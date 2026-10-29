#!/usr/bin/env python3
"""The preview helper operates on temporary repositories and mock desktop IPC."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("preview", Path(__file__).resolve().parent.parent / "scripts/taskbar-preview.py")
PREVIEW = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREVIEW)


class PreviewTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="omacale-preview-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.checkout = self.root / "checkout"
        self.config = self.root / "config"
        self.state = self.root / "state"
        self.source.mkdir()
        self.git("init", "-b", "main", cwd=self.source)
        self.git("config", "user.name", "Test", cwd=self.source)
        self.git("config", "user.email", "test@example.invalid", cwd=self.source)
        (self.source / "Bar.qml").write_text("old source")
        self.git("add", ".", cwd=self.source)
        self.git("commit", "-m", "base", cwd=self.source)
        self.git("switch", "-c", "feat/taskbar-apps", cwd=self.source)
        (self.source / "Bar.qml").write_text("preview source")
        (self.source / "new.qml").write_text("new component")
        self.git("add", ".", cwd=self.source)
        self.git("commit", "-m", "feature", cwd=self.source)
        self.git("clone", "--no-hardlinks", "--branch", "main", str(self.source), str(self.checkout))
        self.plugin = self.config / "omarchy/plugins/omacale.bar"
        self.plugin.mkdir(parents=True)
        (self.plugin / "Bar.qml").write_text("installed before")
        PREVIEW.write_json(self.config / "omarchy/shell.json", {"bar": {"id": "omacale.bar"}})
        self.settings = self.config / "omacale/settings.json"
        self.before = {"bar": {"apps": {"enabled": False}, "layout": {"removed": ["apps"]}}, "general": {"clock24": False}}
        PREVIEW.write_json(self.settings, self.before)
        self.real_run = PREVIEW.run
        self.fail_status = False
        self.desktop_calls = []
        self.patcher = patch.object(PREVIEW, "run", side_effect=self.dispatch)
        self.patcher.start()
        self.sleep_patcher = patch.object(PREVIEW.time, "sleep")
        self.sleep_patcher.start()
        self.addCleanup(self.sleep_patcher.stop)
        self.addCleanup(self.patcher.stop)

    def git(self, *args, cwd=None):
        return subprocess.check_output(["git", *args], cwd=cwd, text=True, stderr=subprocess.DEVNULL).strip()

    def dispatch(self, *args, cwd=None):
        if args[0] in ("hyprctl", "omarchy-shell", "omarchy-restart-shell", "grim"):
            self.desktop_calls.append(args)
            if args[-1] == "taskbarAppsStatus":
                return "bad JSON" if self.fail_status else '{"enabled": true, "items": 2, "pinned": 0}'
            return "ok"
        return self.real_run(*args, cwd=cwd)

    def test_install_and_restore_preserve_other_settings(self):
        PREVIEW.start(self.source, self.config, self.state, self.checkout)
        self.assertEqual(self.git("branch", "--show-current", cwd=self.checkout), "feat/taskbar-apps")
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "preview source")
        current = PREVIEW.read_json(self.settings)
        self.assertTrue(current["bar"]["apps"]["enabled"])
        self.assertEqual(current["bar"]["layout"]["removed"], [])
        self.assertIn("apps", current["bar"]["layout"]["start"])
        self.assertIn(("omarchy-shell", "omacale", "settingsPage", "taskbarApps"), self.desktop_calls)
        current["general"]["clock24"] = True
        PREVIEW.write_json(self.settings, current)
        PREVIEW.restore(self.state)
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")
        self.assertFalse((self.plugin / "new.qml").exists())
        restored = PREVIEW.read_json(self.settings)
        self.assertEqual(restored["bar"], self.before["bar"])
        self.assertTrue(restored["general"]["clock24"])
        self.assertEqual(self.git("branch", "--show-current", cwd=self.checkout), "main")
        self.assertFalse((self.state / "active.json").exists())

    def test_failed_runtime_probe_rolls_back(self):
        self.fail_status = True
        with self.assertRaises(ValueError):
            PREVIEW.start(self.source, self.config, self.state, self.checkout)
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")
        self.assertEqual(PREVIEW.read_json(self.settings), self.before)
        self.assertEqual(self.git("branch", "--show-current", cwd=self.checkout), "main")

    def test_dirty_checkout_is_rejected_before_deployment(self):
        (self.checkout / "mine.txt").write_text("keep me")
        with self.assertRaisesRegex(RuntimeError, "uncommitted"):
            PREVIEW.start(self.source, self.config, self.state, self.checkout)
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")
        self.assertFalse((self.state / "active.json").exists())

    def test_restore_leaves_user_edits_on_feature_branch(self):
        PREVIEW.start(self.source, self.config, self.state, self.checkout)
        (self.checkout / "mine.txt").write_text("keep me")
        PREVIEW.restore(self.state)
        self.assertEqual(self.git("branch", "--show-current", cwd=self.checkout), "feat/taskbar-apps")
        self.assertEqual((self.checkout / "mine.txt").read_text(), "keep me")
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")


if __name__ == "__main__":
    unittest.main()
