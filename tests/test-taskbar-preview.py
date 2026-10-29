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
        self.stopped = False
        self.events = []
        self.supervisor_patcher = patch.object(PREVIEW, "shell_launchers", return_value=[])
        self.supervisor_patcher.start()
        self.addCleanup(self.supervisor_patcher.stop)
        self.inventory_patcher = patch.object(PREVIEW, "assert_stopped")
        self.inventory_patcher.start()
        self.addCleanup(self.inventory_patcher.stop)
        self.real_stop = PREVIEW.stop_shell
        self.real_publish = PREVIEW.publish_plugin
        self.stop_patcher = patch.object(PREVIEW, "stop_shell", side_effect=self.stop_shell)
        self.stop_patcher.start()
        self.addCleanup(self.stop_patcher.stop)
        self.unlock_patcher = patch.object(PREVIEW, "ensure_unlocked")
        self.unlock_patcher.start()
        self.addCleanup(self.unlock_patcher.stop)
        self.publish_patcher = patch.object(PREVIEW, "publish_plugin", side_effect=self.publish_plugin)
        self.publish_patcher.start()
        self.addCleanup(self.publish_patcher.stop)
        self.crash_patcher = patch.object(PREVIEW, "crash_reports", return_value=set())
        self.crash_patcher.start()
        self.addCleanup(self.crash_patcher.stop)
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

    def stop_shell(self):
        self.events.append("stop:" + (self.plugin / "Bar.qml").read_text())
        self.stopped = True
        return self.root / "shell"

    def publish_plugin(self, stage, plugin):
        self.assertTrue(self.stopped, "Publishing while the shell is running")
        self.assertTrue(stage.name.startswith(".omacale-taskbar-stage-"))
        self.events.append("publish:" + (stage / "Bar.qml").read_text())
        self.real_publish(stage, plugin)

    def dispatch(self, *args, cwd=None, timeout=10):
        if args[0] in ("hyprctl", "omarchy-shell", "omarchy-restart-shell", "grim"):
            self.desktop_calls.append(args)
            if args[0] == "omarchy-restart-shell":
                self.events.append("restart:" + (self.plugin / "Bar.qml").read_text())
                self.stopped = False
            if args[-1] == "taskbarAppsStatus":
                return "bad JSON" if self.fail_status else '{"enabled": true, "items": 2, "pinned": 0, "screens": [{"ready": true}]}'
            return "ok"
        return self.real_run(*args, cwd=cwd, timeout=timeout)

    def test_cli_start_dispatches_through_the_transaction_lock(self):
        with patch.object(sys, "argv", ["taskbar-preview.py", "start"]), \
             patch.object(Path, "home", return_value=self.root), \
             patch.dict(PREVIEW.os.environ, {"XDG_STATE_HOME":str(self.root)}), \
             patch.object(PREVIEW, "start") as workflow:
            self.assertEqual(PREVIEW.main(), 0)
        workflow.assert_called_once()
        self.assertTrue((self.root/"omacale/taskbar-preview/lock").exists())
        self.assertEqual(self.desktop_calls, [])

    def test_quickshell_no_instances_text_is_a_valid_empty_inventory(self):
        with patch.object(PREVIEW, "run", return_value="No running instances."):
            self.assertEqual(PREVIEW.shell_instances(self.root / "shell"), [])

    def test_inventory_filters_actual_json_for_this_shell(self):
        config = self.root / "shell"
        output = json.dumps([{"config_path":str(config / "shell.qml")},
                             {"config_path":str(self.root / "other/shell.qml")}])
        with patch.object(PREVIEW, "run", return_value=output):
            self.assertEqual(len(PREVIEW.shell_instances(config)), 1)

    def test_bad_inventory_after_quit_restarts_before_propagating_error(self):
        with patch.object(PREVIEW, "shell_config", return_value=self.root / "shell"), \
             patch.object(PREVIEW, "shell_instances", side_effect=[[{"id":"first"}], ValueError("bad inventory")]), \
             patch.object(PREVIEW, "run") as commands:
            with self.assertRaisesRegex(ValueError, "bad inventory"):
                self.real_stop()
        self.assertEqual(commands.call_args_list[-1].args, ("omarchy-restart-shell",))

    def test_stop_preserves_inventory_error_when_recovery_also_fails(self):
        with patch.object(PREVIEW, "shell_config", return_value=self.root / "shell"), \
             patch.object(PREVIEW, "shell_instances", side_effect=[[{"id":"first"}], ValueError("bad inventory")]), \
             patch.object(PREVIEW, "run", side_effect=["", RuntimeError("restart failed")]):
            with self.assertRaisesRegex(ValueError, "bad inventory"):
                self.real_stop()

    def test_staging_and_retired_directories_are_outside_the_watch_tree(self):
        stage = PREVIEW.stage_plugin(self.source, self.plugin)
        self.assertFalse(stage.is_relative_to(self.plugin.parent))
        self.assertEqual(stage.stat().st_dev, self.plugin.stat().st_dev)
        self.real_publish(stage, self.plugin)
        self.assertEqual(list(self.plugin.parent.iterdir()), [self.plugin])

    def test_original_failure_survives_failed_restore(self):
        with patch.object(PREVIEW, "wait_ready", side_effect=RuntimeError("original probe")), \
             patch.object(PREVIEW, "restore", side_effect=RuntimeError("recovery failed")):
            with self.assertRaisesRegex(RuntimeError, "original probe"):
                PREVIEW.start(self.source, self.config, self.state)
        self.assertEqual(PREVIEW.read_json(self.state / "failure.json")["error"], "original probe")

    def test_real_no_instances_response_finishes_stop_without_parse_error(self):
        config = self.root / "shell"
        responses = [json.dumps([{"config_path":str(config / "shell.qml")}]), "", "No running instances."]
        with patch.object(PREVIEW, "shell_config", return_value=config), \
             patch.object(PREVIEW, "run", side_effect=responses) as commands:
            self.assertEqual(self.real_stop(), config)
        self.assertEqual(commands.call_args_list[1].args[:2], ("quickshell", "kill"))

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
        self.assertEqual(self.events, [
            "stop:installed before", "publish:preview source", "restart:preview source",
            "stop:preview source", "publish:installed before", "restart:installed before"])

    def test_failed_runtime_probe_rolls_back(self):
        with patch.object(PREVIEW, "wait_ready", side_effect=[RuntimeError("probe failed"), "1"]):
            with self.assertRaisesRegex(RuntimeError, "probe failed"):
                PREVIEW.start(self.source, self.config, self.state, self.checkout)
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")
        self.assertEqual(PREVIEW.read_json(self.settings), self.before)
        self.assertEqual(self.git("branch", "--show-current", cwd=self.checkout), "main")
        self.assertEqual(PREVIEW.read_json(self.state / "failure.json")["error"], "probe failed")

    def test_new_app_settings_roll_back_only_the_preview_enable_leaf(self):
        before = {"bar":{"layout":{"start":["logo"]}}}
        applied = {"bar":{"layout":{"start":["logo","apps"]},"apps":{"enabled":True}}}
        current = {"bar":{"layout":{"start":["logo","apps"]},"apps":{"enabled":True,"maxShown":3}}}
        self.assertEqual(PREVIEW.undo_settings(current,before,applied),
                         {"bar":{"layout":{"start":["logo"]},"apps":{"maxShown":3}}})
        self.assertEqual(PREVIEW.undo_settings(applied,before,applied),before)

    def test_failed_publish_restarts_the_original_shell(self):
        with patch.object(PREVIEW, "publish_plugin", side_effect=OSError("publish failed")):
            with self.assertRaisesRegex(OSError,"publish failed"):
                PREVIEW.start(self.source,self.config,self.state)
        self.assertEqual(self.events,["stop:installed before","restart:installed before"])
        self.assertFalse(self.stopped)
        self.assertEqual((self.plugin/"Bar.qml").read_text(),"installed before")
        self.assertFalse((self.state/"active.json").exists())

    def test_restore_preserves_later_edits_inside_app_settings(self):
        PREVIEW.start(self.source, self.config, self.state)
        current = PREVIEW.read_json(self.settings)
        current["bar"]["apps"]["maxShown"] = 3
        PREVIEW.write_json(self.settings, current)
        PREVIEW.restore(self.state)
        self.assertEqual(PREVIEW.read_json(self.settings)["bar"]["apps"], {"enabled":False,"maxShown":3})

    def test_restore_refuses_to_overwrite_installed_plugin_edits(self):
        PREVIEW.start(self.source, self.config, self.state)
        (self.plugin / "Bar.qml").write_text("user changed it")
        calls = len(self.events)
        with self.assertRaisesRegex(RuntimeError, "changed since preview"):
            PREVIEW.restore(self.state)
        self.assertEqual(len(self.events), calls)
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "user changed it")
        self.assertFalse(self.stopped)

    def test_failed_diagnostic_write_cannot_skip_shell_recovery(self):
        write_json = PREVIEW.write_json
        def write(path,value):
            if path.name == "failure.json":raise OSError("diagnostic disk full")
            return write_json(path,value)
        with patch.object(PREVIEW,"write_json",side_effect=write), \
             patch.object(PREVIEW,"wait_ready",side_effect=[RuntimeError("original probe failure"),"1"]):
            with self.assertRaisesRegex(RuntimeError,"original probe failure"):
                PREVIEW.start(self.source,self.config,self.state)
        self.assertFalse(self.stopped)
        self.assertEqual((self.plugin/"Bar.qml").read_text(),"installed before")

    def test_cleanup_failure_after_publish_keeps_the_committed_phase(self):
        stage = PREVIEW.stage_plugin(self.source,self.plugin)
        with patch.object(PREVIEW.shutil,"rmtree",side_effect=OSError("cleanup denied")):
            self.real_publish(stage,self.plugin)
        self.assertEqual((self.plugin/"Bar.qml").read_text(),"preview source")
        self.assertFalse(stage.exists())

    def test_failed_copy_keeps_original_error_when_cleanup_also_fails(self):
        with patch.object(PREVIEW.shutil,"copytree",side_effect=OSError("original copy failure")), \
             patch.object(PREVIEW.shutil,"rmtree",side_effect=OSError("cleanup denied")):
            with self.assertRaisesRegex(OSError,"original copy failure"):
                PREVIEW.stage_plugin(self.source,self.plugin)

    def test_dirty_checkout_is_rejected_before_deployment(self):
        (self.checkout / "mine.txt").write_text("keep me")
        with self.assertRaisesRegex(RuntimeError, "uncommitted"):
            PREVIEW.start(self.source, self.config, self.state, self.checkout)
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")
        self.assertFalse((self.state / "active.json").exists())

    def test_copy_failure_never_changes_the_installed_module(self):
        with patch.object(PREVIEW, "stage_plugin", side_effect=OSError("disk full")):
            with self.assertRaisesRegex(OSError, "disk full"):
                PREVIEW.start(self.source, self.config, self.state, self.checkout)
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")
        self.assertEqual(self.events, [])
        self.assertEqual(self.git("branch", "--show-current", cwd=self.checkout), "main")

    def test_readiness_waits_for_the_entry_not_only_core_ping(self):
        replies = [RuntimeError("no such target"), '{"enabled":true,"screens":[]}',
                   '{"enabled":true,"screens":[{"ready":false}]}',
                   '{"enabled":true,"screens":[{"ready":true}]}']
        with patch.object(PREVIEW, "run", side_effect=replies) as probe:
            reply = PREVIEW.wait_ready(("status",), PREVIEW.apps_ready)
        self.assertTrue(PREVIEW.apps_ready(reply))
        self.assertEqual(probe.call_count, 4)

    def test_new_native_crash_aborts_before_another_probe(self):
        with patch.object(PREVIEW, "crash_reports", return_value={"new/report.txt"}):
            with self.assertRaisesRegex(RuntimeError, "Quickshell crashed"):
                PREVIEW.wait_ready(("status",), PREVIEW.apps_ready, crashes=set())

    def test_existing_feature_branch_is_only_fast_forwarded(self):
        self.git("branch", "feat/taskbar-apps", "main", cwd=self.checkout)
        PREVIEW.start(self.source, self.config, self.state, self.checkout)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.checkout),
                         self.git("rev-parse", "HEAD", cwd=self.source))

    def test_diverged_feature_branch_is_rejected_without_installing(self):
        self.git("switch", "-c", "feat/taskbar-apps", cwd=self.checkout)
        self.git("config", "user.name", "Test", cwd=self.checkout)
        self.git("config", "user.email", "test@example.invalid", cwd=self.checkout)
        (self.checkout / "mine.txt").write_text("my work")
        self.git("add", ".", cwd=self.checkout)
        self.git("commit", "-m", "my work", cwd=self.checkout)
        self.git("switch", "main", cwd=self.checkout)
        with self.assertRaisesRegex(RuntimeError, "diverged"):
            PREVIEW.start(self.source, self.config, self.state, self.checkout)
        self.assertEqual(self.events, [])
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")

    def test_failed_atomic_publish_puts_the_old_directory_back(self):
        stage = PREVIEW.stage_plugin(self.source, self.plugin)
        original = Path.rename
        def rename(path, destination):
            if path == stage:
                raise OSError("rename failed")
            return original(path, destination)
        with patch.object(Path, "rename", rename):
            with self.assertRaisesRegex(OSError, "rename failed"):
                self.real_publish(stage, self.plugin)
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")
        self.assertFalse((self.plugin / "new.qml").exists())

    def test_stop_waits_for_all_instances_before_returning(self):
        config = self.root / "shell"
        with patch.object(PREVIEW, "shell_config", return_value=config), \
             patch.object(PREVIEW, "shell_instances", side_effect=[[{"id":"first"}], [{"id":"last"}], []]), \
             patch.object(PREVIEW, "run") as commands:
            self.assertEqual(self.real_stop(), config)
        self.assertEqual(commands.call_count, 2)
        for command in commands.call_args_list:
            self.assertEqual(command.args[:3], ("quickshell", "kill", "-p"))

    def test_stop_waits_out_supervisor_backoff_and_stops_its_replacement(self):
        config = self.root / "shell"
        with patch.object(PREVIEW, "shell_config", return_value=config), \
             patch.object(PREVIEW, "shell_instances", side_effect=[[], [{"id":"replacement"}], []]), \
             patch.object(PREVIEW, "shell_launchers", side_effect=[[42], [42], []]), \
             patch.object(PREVIEW, "run") as commands:
            self.assertEqual(self.real_stop(), config)
        self.assertEqual(commands.call_count, 1)
        self.assertEqual(commands.call_args.args[:2], ("quickshell", "kill"))

    def test_stop_rejects_locked_or_unknown_state_before_killing(self):
        with patch.object(PREVIEW, "ensure_unlocked", side_effect=RuntimeError("locked")), \
             patch.object(PREVIEW, "run") as commands:
            with self.assertRaisesRegex(RuntimeError, "locked"):
                self.real_stop()
        commands.assert_not_called()

    def test_restore_leaves_user_edits_on_feature_branch(self):
        PREVIEW.start(self.source, self.config, self.state, self.checkout)
        (self.checkout / "mine.txt").write_text("keep me")
        PREVIEW.restore(self.state)
        self.assertEqual(self.git("branch", "--show-current", cwd=self.checkout), "feat/taskbar-apps")
        self.assertEqual((self.checkout / "mine.txt").read_text(), "keep me")
        self.assertEqual((self.plugin / "Bar.qml").read_text(), "installed before")


if __name__ == "__main__":
    unittest.main()
