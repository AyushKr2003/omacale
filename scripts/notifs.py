#!/usr/bin/env python3
"""Omarchy's notification records as JSON, newest first.

Omarchy's notification daemon keeps one file per notification: while a toast
is on screen its file sits in ~/.local/state/omarchy/notifications/, and when
the toast goes it moves down into history/. There is no IPC that hands the
whole set over, so we read the files.

  (no argument)   live popups + history, deduped -- the sidebar's centre.
  live            only the popups currently on screen.
  watch           `live`, printed once now and again on every change, one
                  JSON object per line. A toast has to appear the moment its
                  file does, and one long-lived process polling a four-entry
                  directory is far cheaper than respawning this script.
"""
import glob, json, os, sys, time

state_dir = os.path.expanduser("~/.local/state/omarchy/notifications")
hist_dir = os.path.join(state_dir, "history")

# The record Omarchy's daemon writes (NotificationLogic.js historyEntry /
# popupEntry), with the defaults it fills in itself. A record from a newer
# Omarchy that lacks a field, or carries one of another type, is shown with
# these rather than dropped -- or, worse, sinking the whole list: a bad
# timestamp used to crash the sort and empty the sidebar. Unknown fields are
# passed through untouched.
FIELDS = {
    "id": 0, "originalId": 0, "app": "", "appIcon": "", "summary": "", "body": "",
    "image": "", "glyph": "", "execArgv": "", "urgency": 1, "expireTimeout": 0,
    "timestamp": 0,
}
NUMERIC = ("id", "originalId", "urgency", "expireTimeout", "timestamp", "deadline")
EXPECTED = ("summary", "timestamp")
warned = False


def warn_once(what):
    """One line on stderr per process: enough to notice a format change,
    not a flood from the watcher's ten reads a second."""
    global warned
    if not warned:
        warned = True
        print("notifs.py: %s; showing it with Omarchy's defaults" % what, file=sys.stderr)


def number(value, default):
    try:
        n = float(value)
    except (TypeError, ValueError):
        return default
    if n != n or n in (float("inf"), float("-inf")):
        return default
    return int(n) if n == int(n) else n


def normalize(d):
    if not isinstance(d, dict):
        raise ValueError("not a notification record")
    missing = [k for k in EXPECTED if k not in d]
    if missing:
        warn_once("a notification record has no %s (fields: %s)" % (", ".join(missing), ", ".join(sorted(d))))
    for key, default in FIELDS.items():
        if d.get(key) is None:
            d[key] = default
    for key in NUMERIC:
        if key in d:
            d[key] = number(d[key], FIELDS.get(key, 0))
    for key in ("app", "appIcon", "summary", "body", "image", "glyph"):
        if not isinstance(d[key], str):
            d[key] = str(d[key])
    if not d["originalId"]:
        d["originalId"] = d["id"]
    return d


def collect(live_only):
    files = glob.glob(os.path.join(state_dir, "*.json"))
    if not live_only:
        files += glob.glob(os.path.join(hist_dir, "*.json"))
    seen = set()
    notifs = []

    for f in files:
        try:
            with open(f, "r", encoding="utf-8", errors="replace") as fp:
                d = normalize(json.load(fp))
                key = (d["id"], d["timestamp"], d["app"], d["summary"])
                if key in seen:
                    continue
                seen.add(key)
                d["_file"] = f
                # The daemon names each file after the popup it holds; that
                # stem is how Omacale addresses one popup over IPC.
                d["_key"] = os.path.basename(f)[:-5]
                notifs.append(d)
        except Exception:
            pass

    notifs.sort(key=lambda x: x["timestamp"], reverse=True)
    return notifs


def signature():
    """Cheap fingerprint of the live directory: names, sizes and mtimes.

    Size and mtime both matter -- the daemon writes a popup's file twice, once
    when the toast appears and again to stamp its expiry deadline on it.
    """
    try:
        with os.scandir(state_dir) as entries:
            out = []
            for entry in entries:
                if not entry.name.endswith(".json"):
                    continue
                st = entry.stat()
                out.append((entry.name, st.st_size, st.st_mtime_ns))
            return tuple(sorted(out))
    except OSError:
        return ()


def watch():
    last = None
    while True:
        current = signature()
        if current != last:
            last = current
            print(json.dumps(collect(True)), flush=True)
        time.sleep(0.1)


mode = sys.argv[1] if len(sys.argv) > 1 else ""
if mode == "watch":
    try:
        watch()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
else:
    print(json.dumps(collect(mode == "live")))
