#!/usr/bin/env python3
"""Quit only disposable processes; compositor replies are deterministic fixtures."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("quit_app", Path(__file__).resolve().parents[1] / "scripts/taskbar-quit.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class QuitTests(unittest.TestCase):
    def setUp(self):
        self.child = subprocess.Popen(["/usr/bin/sleep", "60"])
        self.other = subprocess.Popen(["/usr/bin/sleep", "60"])
        self.window = {"address": "0xabc", "pid": self.child.pid, "class": "test-app"}
        self.windows = [dict(self.window)]
        self.closed = []

    def tearDown(self):
        for process in [self.child, self.other]:
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=2)

    def close(self, address):
        self.closed.append(address)
        self.windows = [w for w in self.windows if w["address"] != address]

    def run_quit(self, **kwargs):
        return module.quit_app([self.window], lambda: list(self.windows), self.close, close_timeout=0, **kwargs)

    def test_closes_all_selected_windows_and_ends_background_process_only(self):
        second = dict(self.window, address="0xdef")
        self.windows.append(second)
        result = module.quit_app([self.window, second], lambda: list(self.windows), self.close)
        self.assertEqual(result["state"], "closed")
        self.assertEqual(self.closed, ["0xabc", "0xdef"])
        self.assertEqual(self.child.wait(timeout=2), -15)
        self.assertIsNone(self.other.poll())

    def test_does_not_terminate_shared_browser(self):
        other_window = dict(self.window, address="0xdef", **{"class": "another-web-app"})
        self.windows.append(other_window)
        self.assertEqual(self.run_quit()["state"], "closed")
        self.assertIsNone(self.child.poll())
        self.assertEqual(self.windows, [other_window])

    def test_web_app_does_not_terminate_browser_even_without_other_windows(self):
        self.assertEqual(self.run_quit(terminate=False)["state"], "closed")
        self.assertIsNone(self.child.poll())

    def test_unsaved_window_is_not_bypassed(self):
        result = module.quit_app([self.window], lambda: list(self.windows), lambda a: None, close_timeout=0)
        self.assertEqual(result["state"], "windows-open")
        self.assertIsNone(self.child.poll())

    def test_new_save_dialog_is_not_bypassed(self):
        def close_and_prompt(address):
            self.close(address)
            self.windows.append(dict(self.window, address="0xdef"))
        result = module.quit_app([self.window], lambda: list(self.windows), close_and_prompt, close_timeout=0)
        self.assertEqual(result["state"], "windows-open")
        self.assertIsNone(self.child.poll())

    def test_changed_compositor_pid_is_refused(self):
        self.windows[0]["pid"] = self.other.pid
        with self.assertRaises(ValueError):
            self.run_quit()
        self.assertIsNone(self.child.poll())
        self.assertIsNone(self.other.poll())
        self.assertEqual(self.closed, [])

    def test_changed_identity_after_pidfd_open_is_refused(self):
        calls = 0
        def snapshot():
            nonlocal calls
            calls += 1
            return [dict(self.window, pid=self.other.pid)] if calls > 1 else [self.window]
        with self.assertRaises(ValueError):
            module.quit_app([self.window], snapshot, self.close)
        self.assertEqual(self.closed, [])
        self.assertIsNone(self.other.poll())

    def test_shell_and_malformed_targets_are_refused(self):
        with patch.dict(os.environ, {"OMACALE_SHELL_PID": str(self.child.pid)}):
            with self.assertRaises(ValueError):
                self.run_quit()
        for targets in [[], [7], [{"address": "0xabc;bad", "pid": self.child.pid, "class": "test-app"}]]:
            with self.assertRaises(ValueError):
                module.quit_app(targets)
        self.assertIsNone(self.child.poll())


if __name__ == "__main__":
    unittest.main()
