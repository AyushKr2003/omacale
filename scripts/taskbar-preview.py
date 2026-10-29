#!/usr/bin/env python3
"""Preview taskbar apps in the existing shell, with an explicit rollback."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


def run(*args, cwd=None, timeout=10):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Command failed: " + args[0])
    return result.stdout.strip()


def read_json(path):
    return json.loads(path.read_text()) if path.exists() else {}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def shell_config():
    # Match omarchy-restart-shell: the user manager owns the desktop's path.
    result = subprocess.run(["systemctl", "--user", "show-environment"],
                            capture_output=True, text=True, timeout=5)
    path = next((line.partition("=")[2] for line in result.stdout.splitlines()
                 if line.startswith("OMARCHY_PATH=")), os.environ.get("OMARCHY_PATH", ""))
    config = Path(path) / "shell" if path else None
    if not config or not (config / "shell.qml").is_file():
        raise RuntimeError("Cannot identify the running Omarchy shell configuration")
    return config.resolve()


def shell_instances(config):
    output = run("quickshell", "list", "-a", "-j")
    # Quickshell prints this success message even when JSON was requested.
    if output == "No running instances.":
        return []
    rows = json.loads(output)
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise RuntimeError("Unexpected Quickshell instance-list response")
    return [row for row in rows
            if Path(row.get("config_path", "")).resolve() == config / "shell.qml"]


def ensure_unlocked():
    probe = subprocess.run(["omarchy-hyprland-session-locked"], capture_output=True, timeout=5)
    if probe.returncode != 1:
        raise RuntimeError("Desktop is locked or its lock state is unknown; shell left running")


def stop_shell():
    ensure_unlocked()
    config = shell_config()
    deadline = time.monotonic() + 30
    stop_attempted = False
    try:
        while shell_instances(config):
            if time.monotonic() >= deadline:
                raise RuntimeError("Existing shell did not stop; installed plugin left untouched")
            stop_attempted = True
            run("quickshell", "kill", "-p", str(config), "--any-display", timeout=30)
            time.sleep(0.05)
    except BaseException:
        # A failed inventory query can happen after quit was delivered. Never
        # leave the desktop stopped just because this function did not return.
        if stop_attempted:
            print("Shell stop verification failed; restarting the existing version...", file=sys.stderr, flush=True)
            run("omarchy-restart-shell", timeout=180)
        raise
    return config


def stage_plugin(source, plugin, development=False):
    # The registry ignores hidden entries. It must never see a half-written
    # module, including during recovery or a failed copy.
    stage = Path(tempfile.mkdtemp(prefix=".omacale-taskbar-stage-", dir=plugin.parent))
    try:
        ignored = [".git", "__pycache__"] + (["tests"] if development else [])
        shutil.copytree(source, stage, dirs_exist_ok=True, symlinks=True,
                        ignore=shutil.ignore_patterns(*ignored))
        return stage
    except BaseException:
        shutil.rmtree(stage)
        raise


def publish_plugin(stage, plugin):
    # Called only after confirming that the existing shell has exited.
    retired = plugin.parent / (".omacale-taskbar-old-" + uuid.uuid4().hex)
    plugin.rename(retired)
    try:
        stage.rename(plugin)
    except BaseException:
        retired.rename(plugin)
        raise
    shutil.rmtree(retired)


def crash_reports():
    root = Path.home() / ".cache/quickshell/crashes"
    return {str(p) for p in root.glob("*/report.txt")}


def wait_ready(args, validate, crashes=None, timeout=30):
    deadline = time.monotonic() + timeout
    last = "Plugin is not ready yet"
    while time.monotonic() < deadline:
        if crashes is not None and (new := crash_reports() - crashes):
            raise RuntimeError("Quickshell crashed during startup: " + ", ".join(sorted(new)))
        try:
            reply = run(*args, timeout=2)
            if validate(reply):
                return reply
            last = "Plugin replied but its taskbar entry is not ready"
        except (RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
            last = str(error)
        time.sleep(0.1)
    raise RuntimeError("Timed out waiting for Omacale: " + last)


def apps_ready(reply):
    status = json.loads(reply)
    return (status.get("enabled") is True
            and any(screen.get("ready") is True for screen in status.get("screens", [])))


def restore(state_dir, restart=True):
    record_path = state_dir / "active.json"
    if not record_path.exists():
        raise RuntimeError("No active taskbar preview to restore")
    record = read_json(record_path)
    plugin = Path(record["plugin"])
    if not (state_dir / "plugin-before/Bar.qml").is_file():
        raise RuntimeError("The saved plugin backup is missing; installed files were left untouched")
    if plugin.is_symlink():
        raise RuntimeError("The installed plugin became a symlink; refusing to replace its target")
    stage = stage_plugin(state_dir / "plugin-before", plugin)
    shell_stopped = False
    try:
        print("Stopping the existing shell before restoring files...", flush=True)
        stop_shell()
        shell_stopped = True
        publish_plugin(stage, plugin)
        settings = Path(record["settings"])
        current = read_json(settings)
        bar = current.setdefault("bar", {})
        for key, before in record["barBefore"].items():
            if before["present"]:
                bar[key] = before["value"]
            else:
                bar.pop(key, None)
        write_json(settings, current)
        checkout = record.get("checkout")
        if checkout:
            checkout = Path(checkout)
            if (not run("git", "status", "--porcelain", cwd=checkout)
                    and run("git", "rev-parse", "HEAD", cwd=checkout) == record["previewHead"]):
                run("git", "switch", record["previousBranch"], cwd=checkout)
            else:
                print("Checkout has changed; left its branch and files untouched.")
        if restart:
            run("omarchy-restart-shell", timeout=180)
            shell_stopped = False
            wait_ready(("omarchy-shell", "omacale", "scale", ""), bool)
        record_path.rename(state_dir / "restored.json")
        print("Previous plugin, app settings and bar layout restored. Other settings were kept.")
    finally:
        if shell_stopped and restart:
            run("omarchy-restart-shell", timeout=180)
        if stage.exists():
            shutil.rmtree(stage)


def start(source, config, state_dir, checkout=None):
    if (state_dir / "active.json").exists():
        raise RuntimeError("A preview is already active. Use restore before starting another")
    plugin = config / "omarchy/plugins/omacale.bar"
    settings = config / "omacale/settings.json"
    if plugin.is_symlink() or not (plugin / "Bar.qml").is_file():
        raise RuntimeError("This helper needs an existing regular Omacale plugin directory")
    if read_json(config / "omarchy/shell.json").get("bar", {}).get("id") != "omacale.bar":
        raise RuntimeError("Omacale must already be the selected bar")
    ensure_unlocked()
    run("hyprctl", "monitors", "-j")
    run("omarchy-shell", "shell", "ping")
    head = run("git", "rev-parse", "HEAD", cwd=source)
    branch = run("git", "symbolic-ref", "--short", "HEAD", cwd=source)
    if run("git", "status", "--porcelain", cwd=source):
        raise RuntimeError("Commit or stash source changes before previewing")
    previous = ""
    checkout = checkout.resolve() if checkout else None
    if checkout and checkout.resolve() != source.resolve():
        if run("git", "status", "--porcelain", cwd=checkout):
            raise RuntimeError("The destination checkout has uncommitted changes")
        previous = run("git", "symbolic-ref", "--short", "HEAD", cwd=checkout)
        if previous == branch:
            raise RuntimeError("Destination already uses this branch; omit --checkout to preview it")
        run("git", "fetch", "--no-tags", str(source), branch, cwd=checkout)
        existing = subprocess.run(["git", "rev-parse", "--verify", "refs/heads/" + branch], cwd=checkout,
                                  capture_output=True, text=True)
        if existing.returncode == 0 and existing.stdout.strip() != head:
            ancestry = subprocess.run(["git", "merge-base", "--is-ancestor", existing.stdout.strip(), head],
                                      cwd=checkout, capture_output=True)
            if ancestry.returncode != 0:
                raise RuntimeError("Destination branch has diverged; refusing to overwrite it")
    else:
        checkout = None
    state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup = state_dir / "plugin-before"
    if backup.exists():
        shutil.rmtree(backup)
    shutil.copytree(plugin, backup, symlinks=True)
    current = read_json(settings)
    bar = current.setdefault("bar", {})
    before = {key: {"present": key in bar, "value": bar.get(key)} for key in ("apps", "layout")}
    write_json(state_dir / "active.json", {
        "plugin": str(plugin), "settings": str(settings), "barBefore": before,
        "checkout": str(checkout) if checkout else None,
        "previousBranch": previous, "previewHead": head,
    })
    stage = None
    stopped = False
    deployed = False
    crashes = crash_reports()
    try:
        if checkout:
            if existing.returncode == 0:
                run("git", "switch", branch, cwd=checkout)
                run("git", "merge", "--ff-only", "FETCH_HEAD", cwd=checkout)
            else:
                run("git", "switch", "-c", branch, "FETCH_HEAD", cwd=checkout)
        print("Preparing a complete plugin version...", flush=True)
        stage = stage_plugin(checkout or source, plugin, development=True)
        print("Stopping the existing shell before installing files...", flush=True)
        stop_shell()
        stopped = True
        # Capture settings only after the shell has stopped writing them.
        current = read_json(settings)
        bar = current.setdefault("bar", {})
        record = read_json(state_dir / "active.json")
        record["barBefore"] = {key: {"present": key in bar, "value": bar.get(key)} for key in ("apps", "layout")}
        write_json(state_dir / "active.json", record)
        publish_plugin(stage, plugin)
        deployed = True
        bar.setdefault("apps", {})["enabled"] = True
        layout = bar.setdefault("layout", {})
        for key in ("removed", "drawer"):
            if key in layout:
                layout[key] = [item for item in layout[key] if item != "apps"]
        if not any("apps" in layout.get(key, []) for key in ("start", "center", "end")):
            layout["start"] = layout.get("start", []) + ["apps"]
        write_json(settings, current)
        print("Starting the shell and waiting for the taskbar entry...", flush=True)
        run("omarchy-restart-shell", timeout=180)
        reply = wait_ready(("omarchy-shell", "omacale", "taskbarAppsStatus"), apps_ready, crashes)
        status = json.loads(reply)
        run("omarchy-shell", "omacale", "settingsPage", "taskbarApps")
        print("Taskbar apps are live; Settings > Taskbar > Apps is open.")
        print("Status: " + json.dumps(status))
        if shutil.which("grim"):
            try:
                time.sleep(0.8)
                run("grim", str(state_dir / "preview.png"))
                if (state_dir / "preview.png").exists():
                    print("Screenshot: " + str(state_dir / "preview.png"))
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                print("Screenshot unavailable: " + str(error), file=sys.stderr)
        print("Restore: python3 " + str(source / "scripts/taskbar-preview.py") + " restore")
    except BaseException as error:
        # Report the original failure before any recovery work, not afterwards.
        print("Preview failed: " + str(error), file=sys.stderr, flush=True)
        write_json(state_dir / "failure.json", {"error": str(error), "deployed": deployed,
                                                 "newCrashReports": sorted(crash_reports() - crashes)})
        if stopped or deployed:
            print("Restoring the previous plugin and settings...", file=sys.stderr, flush=True)
            restore(state_dir)
        else:
            # No installed file has changed. Do not stop a locked/busy desktop
            # merely to undo a checkout selection or a preparation error.
            if checkout and not run("git", "status", "--porcelain", cwd=checkout):
                run("git", "switch", previous, cwd=checkout)
            (state_dir / "active.json").unlink()
        raise
    finally:
        if stage and stage.exists():
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("start", "restore"))
    parser.add_argument("--checkout", type=Path, help="Import the feature branch into this clean checkout first")
    args = parser.parse_args()
    if args.action == "start":
        print("Live preview is blocked after two failed desktop trials. "
              "Do not retry it; use omarchy-restart-shell to recover a stopped shell.", file=sys.stderr)
        return 1
    source = Path(__file__).resolve().parent.parent
    config = Path.home() / ".config"
    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "omacale/taskbar-preview"
    try:
        state.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (state / "lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.action == "start":
                start(source, config, state, args.checkout)
            else:
                restore(state)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print("Taskbar preview: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
