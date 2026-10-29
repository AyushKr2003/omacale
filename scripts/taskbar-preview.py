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


def run(*args, cwd=None):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=180)
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
    if plugin.exists():
        shutil.rmtree(plugin)
    shutil.copytree(state_dir / "plugin-before", plugin, symlinks=True)
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
        run("omarchy-restart-shell")
    record_path.rename(state_dir / "restored.json")
    print("Previous plugin, app settings and bar layout restored. Other settings were kept.")


def start(source, config, state_dir, checkout=None):
    if (state_dir / "active.json").exists():
        raise RuntimeError("A preview is already active. Use restore before starting another")
    plugin = config / "omarchy/plugins/omacale.bar"
    settings = config / "omacale/settings.json"
    if plugin.is_symlink() or not (plugin / "Bar.qml").is_file():
        raise RuntimeError("This helper needs an existing regular Omacale plugin directory")
    if read_json(config / "omarchy/shell.json").get("bar", {}).get("id") != "omacale.bar":
        raise RuntimeError("Omacale must already be the selected bar")
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
            raise RuntimeError("Destination branch already differs; refusing to overwrite it")
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
    try:
        if checkout:
            run("git", "switch", branch, cwd=checkout) if existing.returncode == 0 else run("git", "switch", "-c", branch, "FETCH_HEAD", cwd=checkout)
        shutil.copytree(checkout or source, plugin, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns(".git", "__pycache__"))
        bar.setdefault("apps", {})["enabled"] = True
        layout = bar.setdefault("layout", {})
        for key in ("removed", "drawer"):
            if key in layout:
                layout[key] = [item for item in layout[key] if item != "apps"]
        if not any("apps" in layout.get(key, []) for key in ("start", "center", "end")):
            layout["start"] = layout.get("start", []) + ["apps"]
        write_json(settings, current)
        run("omarchy-restart-shell")
        status = json.loads(run("omarchy-shell", "omacale", "taskbarAppsStatus"))
        if status.get("enabled") is not True:
            raise RuntimeError("The new taskbar section did not become enabled")
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
    except BaseException:
        print("Preview failed; restoring the previous plugin and settings.", file=sys.stderr)
        restore(state_dir)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("start", "restore"))
    parser.add_argument("--checkout", type=Path, help="Import the feature branch into this clean checkout first")
    args = parser.parse_args()
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
