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


def collect(live_only):
    files = glob.glob(os.path.join(state_dir, "*.json"))
    if not live_only:
        files += glob.glob(os.path.join(hist_dir, "*.json"))
    seen = set()
    notifs = []

    for f in files:
        try:
            with open(f, "r", encoding="utf-8", errors="replace") as fp:
                d = json.load(fp)
                key = (d.get("id"), d.get("timestamp"), d.get("app"), d.get("summary"))
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

    notifs.sort(key=lambda x: x.get("timestamp", 0), reverse=True)
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
