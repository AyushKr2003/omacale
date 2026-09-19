#!/usr/bin/env python3
import glob, json, os, sys

state_dir = os.path.expanduser("~/.local/state/omarchy/notifications")
hist_dir = os.path.join(state_dir, "history")

files = glob.glob(os.path.join(state_dir, "*.json")) + glob.glob(os.path.join(hist_dir, "*.json"))
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
            notifs.append(d)
    except Exception:
        pass

notifs.sort(key=lambda x: x.get("timestamp", 0), reverse=True)
print(json.dumps(notifs))
