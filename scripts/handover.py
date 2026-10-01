"""Shared by lock-screen and notif-popups: a clone of an Omarchy plugin as a
build artifact, not a fork.

Both handovers go through `omarchy plugin clone`, which copies a first-party
plugin into ~/.config/omarchy/plugins/ once. Left alone, that copy freezes at
the Omarchy it was made from, and upstream fixes (PAM, the stranded-lock
recovery, the notification server) never reach it. So every sync rebuilds the
clone from the installed plugin plus Omacale's small delta:

  * every stock file is copied verbatim, except the ones a handover overrides;
  * files upstream removed are removed from the clone, apart from our own;
  * the manifest keeps the clone's identity (id, name, clonedFrom) and takes
    everything else that decides how the host loads it from stock.

Writes are compare-first: any write under the plugins folder reloads every
plugin, the custom bar included.
"""

import hashlib
import json
import os
import subprocess
import time

# The manifest fields that decide how the host loads a plugin. Identity fields
# (id, name, version, author, description, omarchy.clonedFrom) stay the clone's.
SYNCED_FIELDS = ("schemaVersion", "kinds", "keepLoaded", "entryPoints")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_bytes(path):
    try:
        with open(path, "rb") as f:
            return f.read()
    except OSError:
        return None


def files_under(root):
    """Relative paths of the regular files under root, hidden ones skipped
    (a `.tmp` left by an interrupted write is not part of the plugin)."""
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for name in filenames:
            if name.startswith("."):
                continue
            out.append(os.path.relpath(os.path.join(dirpath, name), root))
    return sorted(out)


def stock_tree(stock_dir):
    """Every stock file but the manifest, as {relpath: bytes}."""
    return {
        rel: read_bytes(os.path.join(stock_dir, rel))
        for rel in files_under(stock_dir)
        if rel != "manifest.json"
    }


def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def desired_manifest(clone_manifest, stock_manifest):
    result = dict(clone_manifest)
    for key in SYNCED_FIELDS:
        if key in stock_manifest:
            result[key] = stock_manifest[key]
        else:
            result.pop(key, None)
    omarchy = dict(result.get("omarchy") or {})
    caps = (stock_manifest.get("omarchy") or {}).get("capabilities")
    if caps is None:
        omarchy.pop("capabilities", None)
    else:
        omarchy["capabilities"] = caps
    result["omarchy"] = omarchy
    return result


class Plan:
    """What the clone should hold, and how far it is from that."""

    def __init__(self, stock_dir, clone, desired, own=()):
        self.clone = clone
        self.desired = desired
        stock_manifest = load_json(os.path.join(stock_dir, "manifest.json")) or {}
        self.clone_manifest = load_json(os.path.join(clone, "manifest.json")) or {}
        self.manifest = desired_manifest(self.clone_manifest, stock_manifest)
        keep = set(desired) | set(own) | {"manifest.json"}
        self.extras = [rel for rel in files_under(clone) if rel not in keep]

    def stale_files(self):
        out = [
            rel for rel, data in sorted(self.desired.items())
            if read_bytes(os.path.join(self.clone, rel)) != data
        ]
        if self.manifest != self.clone_manifest:
            out.append("manifest.json")
        return out + [rel + " (removed upstream)" for rel in self.extras]

    def apply(self):
        """Bring the clone in line. Returns the paths it changed."""
        changed = []
        for rel, data in sorted(self.desired.items()):
            path = os.path.join(self.clone, rel)
            if read_bytes(path) == data:
                continue
            os.makedirs(os.path.dirname(path), exist_ok=True)
            tmp = os.path.join(os.path.dirname(path), "." + os.path.basename(path) + ".tmp")
            with open(tmp, "wb") as f:
                f.write(data)
            os.replace(tmp, path)
            changed.append(rel)
        if self.manifest != self.clone_manifest:
            path = os.path.join(self.clone, "manifest.json")
            tmp = os.path.join(self.clone, ".manifest.json.tmp")
            with open(tmp, "w") as f:
                json.dump(self.manifest, f, indent=2)
                f.write("\n")
            os.replace(tmp, path)
            changed.append("manifest.json")
        for rel in self.extras:
            os.remove(os.path.join(self.clone, rel))
            changed.append(rel)
            # Directories the removal left empty go with it.
            parent = os.path.dirname(os.path.join(self.clone, rel))
            while parent != self.clone and not os.listdir(parent):
                os.rmdir(parent)
                parent = os.path.dirname(parent)
        return changed


# -------------------------------------------------------------------- health

def ipc(*args):
    try:
        proc = subprocess.run(
            ["omarchy-shell", *args], text=True, capture_output=True, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return proc.stdout.strip() if proc.returncode == 0 else None


def shell_up():
    return ipc("shell", "ping") is not None


def checked(probe, tries=None):
    """Run a health probe, giving a plugin that is mid-reload a few seconds to
    come back before calling it broken. Returns (verdict, reason) with verdict
    one of "ok", "fail" or "unknown" (the shell itself is not answering, so
    nothing can be said about the plugin)."""
    if tries is None:
        # Overridable so the sandboxed tests don't sit through the waits.
        raw = os.environ.get("OMACALE_HEALTH_TRIES", "0,3,8")
        tries = [float(t) for t in raw.split(",")]
    reason = ""
    start = time.monotonic()
    for at in tries:
        wait = at - (time.monotonic() - start)
        if wait > 0:
            time.sleep(wait)
        if not shell_up():
            return "unknown", "the shell is not answering"
        ok, reason = probe()
        if ok:
            return "ok", ""
    return "fail", reason
