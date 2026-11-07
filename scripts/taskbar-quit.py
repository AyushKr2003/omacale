#!/usr/bin/python3
"""Close one app's windows, then end only its remaining unshared processes.

Omarchy's dock only closes windows. There is no generic application-quit IPC.
Use compositor-owned window identities, never a process-name match or pkill.
"""
import json
import os
import re
import select
import signal
import socket
import sys
import time


def request(command):
    signature = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", signature):
        raise ValueError("Invalid compositor instance")
    path = os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr", signature, ".socket.sock")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(0.5)
        client.connect(path)
        client.sendall(command.encode())
        chunks, size = [], 0
        while data := client.recv(65536):
            size += len(data)
            if size > 2097152:
                raise ValueError("Compositor reply exceeded its limit")
            chunks.append(data)
        return b"".join(chunks).decode()


def clients():
    rows = json.loads(request("j/clients"))
    if not isinstance(rows, list):
        raise ValueError("Invalid compositor window list")
    return rows


def close(address):
    reply = request('dispatch hl.dsp.window.close({ window = "address:' + address + '" })')
    if reply.strip() != "ok":
        raise RuntimeError("The compositor refused to close a window")


def identity(pid):
    path = f"/proc/{pid}"
    if os.stat(path).st_uid != os.getuid():
        raise ValueError("The application belongs to another user")
    # The command name may itself contain spaces or parentheses.
    with open(path + "/stat") as source:
        return source.read().rsplit(") ", 1)[1].split()[19]


def quit_app(targets, get_clients=clients, close_window=close, close_timeout=2.0, term_timeout=1.0, terminate=True):
    if not isinstance(targets, list) or not 0 < len(targets) <= 256:
        raise ValueError("Invalid application window selection")
    expected = {}
    protected = {os.getpid(), os.getppid(), int(os.environ.get("OMACALE_SHELL_PID", "0"))}
    for target in targets:
        if not isinstance(target, dict):
            raise ValueError("Invalid application window identity")
        address, pid, app_class = target.get("address"), target.get("pid"), target.get("class")
        if (not isinstance(address, str) or not re.fullmatch(r"0x[0-9a-f]+", address)
                or type(pid) is not int or pid <= 1 or pid in protected
                or not isinstance(app_class, str) or not app_class):
            raise ValueError("Invalid application window identity")
        expected[address] = (pid, app_class)
    handles = {}
    try:
        snapshot = get_clients()
        selected = [w for w in snapshot if w.get("address") in expected]
        if not selected:
            return {"state": "gone"}
        for window in selected:
            pid, app_class = expected[window["address"]]
            if (window.get("pid"), window.get("class")) != (pid, app_class):
                raise ValueError("The application window changed; open its menu again")
            if pid not in handles:
                token = identity(pid)
                fd = os.pidfd_open(pid)
                handles[pid] = fd
                if identity(pid) != token:
                    raise ValueError("The application process changed")
        # Validate again after obtaining stable process handles.
        fresh = get_clients()
        for window in fresh:
            if window.get("address") in expected and (window.get("pid"), window.get("class")) != expected[window["address"]]:
                raise ValueError("The application window changed")
        for window in fresh:
            if window.get("address") in expected:
                close_window(window["address"])
        deadline = time.monotonic() + close_timeout
        while True:
            remaining = get_clients()
            if not any(w.get("address") in expected for w in remaining):
                break
            if time.monotonic() >= deadline:
                # A save dialog, unresponsive window, or a refused close is
                # not permission to bypass the application's own close flow.
                return {"state": "windows-open"}
            time.sleep(0.05)
        shared = {w.get("pid") for w in remaining}
        if any((w.get("pid"), w.get("class")) in expected.values() for w in remaining):
            return {"state": "windows-open"}
        signalled = []
        for pid, fd in handles.items():
            if not terminate or pid in shared:
                continue  # A web app must not terminate the shared browser.
            try:
                signal.pidfd_send_signal(fd, signal.SIGTERM)
                signalled.append(fd)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + term_timeout
        for fd in signalled:
            poller = select.poll()
            poller.register(fd, select.POLLIN)
            if not poller.poll(max(0, int((deadline - time.monotonic()) * 1000))):
                return {"state": "still-running"}
        return {"state": "closed"}
    finally:
        for fd in handles.values():
            os.close(fd)


def main():
    try:
        if len(sys.argv) != 2 or len(sys.argv[1]) > 65536:
            raise ValueError("Invalid application selection")
        selection = json.loads(sys.argv[1])
        if not isinstance(selection, dict) or type(selection.get("terminate")) is not bool:
            raise ValueError("Invalid application selection")
        print(json.dumps(quit_app(selection.get("windows"), terminate=selection["terminate"])))
        return 0
    except (OSError, ValueError, RuntimeError, KeyError, TypeError) as error:
        print(json.dumps({"state": "failed", "reason": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
