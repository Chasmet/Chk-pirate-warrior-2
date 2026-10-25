# Tests for the Windows installer; GitHub Actions runs these on windows-latest.
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import importlib.util
import unittest
from unittest import mock
from subprocess import CompletedProcess

module_path = Path(__file__).with_name("chk_godot_installer.py")
spec = importlib.util.spec_from_file_location("godot_installer", module_path)
app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.original = (app.INSTALL_DIR, app.CONFIG_FILE, app.RUNTIME_FILE, app.DIAGNOSTIC_FILE)
        app.INSTALL_DIR = self.root
        app.CONFIG_FILE = self.root / "settings.json"
        app.RUNTIME_FILE = self.root / "runtime.json"
        app.DIAGNOSTIC_FILE = self.root / "diagnostic.log"

    def tearDown(self):
        app.INSTALL_DIR, app.CONFIG_FILE, app.RUNTIME_FILE, app.DIAGNOSTIC_FILE = self.original

    def test_preserve_tokens_across_repeat_install(self):
        a = app.create_config_once()
        b = app.create_config_once()
        self.assertEqual(a, b)
        self.assertEqual(len(a["chat_token"]), 64)
        self.assertNotEqual(a["chat_token"], a["editor_token"])

    def test_immutable_versions_do_not_touch_locked_old_executable(self):
        # WinError 32 arose when code attempted to overwrite node.exe or the
        # running CHK-Godot-Installation.exe. Retain those old files untouched.
        old = self.root / "node.exe"
        old.write_bytes(b"old process holds executable")
        new = self.root / "portable-new.exe"
        new.write_bytes(b"MZ" + b"x" * 700)
        with mock.patch.object(app.shutil, "copy2", side_effect=PermissionError(32, "file in use")):
            a = app.install_immutable(new, "node", ".exe")
            b = app.install_immutable(new, "node", ".exe")
        self.assertEqual(a, b)
        self.assertEqual(a.read_bytes(), new.read_bytes())
        self.assertEqual(old.read_bytes(), b"old process holds executable")

    def test_changed_binary_gets_new_name(self):
        new = self.root / "portable-new.exe"
        new.write_bytes(b"MZ" + b"a" * 700)
        first = app.install_immutable(new, "node", ".exe")
        new.write_bytes(b"MZ" + b"b" * 700)
        second = app.install_immutable(new, "node", ".exe")
        self.assertNotEqual(first, second)
        self.assertTrue(first.exists())
        self.assertTrue(second.exists())

    def test_runtime_saved_for_new_supervisor_without_rotating_keys(self):
        keys = app.create_config_once()
        node = self.root / "node-abc.exe"
        script = self.root / "godot-server-abc.cjs"
        exe = self.root / "CHK-Godot-Application-abc.exe"
        for f in (node, script, exe):
            f.write_text("test", encoding="utf-8")
        app.save_runtime(exe, node, script)
        self.assertEqual((node, script), app.runtime_binaries())
        self.assertEqual(keys, app.installed_config())

    def test_funnel_owns_known_port_even_when_allowfunnel_field_is_missing(self):
        status = {"Web": {"test-machine.ts.net:10000": {"Handlers": {
            "/": {"Proxy": "http://127.0.0.1:8791"}}}}}
        with mock.patch.object(app, "run_hidden", return_value=CompletedProcess([], 0, json.dumps(status), "")):
            self.assertEqual(app.status_10000("tailscale.exe"), "ours")

    def test_funnel_never_overwrites_someone_elses_port(self):
        status = {"Web": {"test-machine.ts.net:10000": {"Handlers": {
            "/": {"Proxy": "http://127.0.0.1:9412"}}}}}
        with mock.patch.object(app, "run_hidden", return_value=CompletedProcess([], 0, json.dumps(status), "")):
            self.assertEqual(app.status_10000("tailscale.exe"), "occupied")

    def test_funnel_empty_port(self):
        status = {"Web": {"test-machine.ts.net:8443": {"Handlers": {
            "/": {"Proxy": "http://127.0.0.1:5000"}}}}}
        with mock.patch.object(app, "run_hidden", return_value=CompletedProcess([], 0, json.dumps(status), "")):
            self.assertEqual(app.status_10000("tailscale.exe"), "empty")

    def test_diagnostic_report_is_local(self):
        try:
            raise PermissionError(32, "file in use")
        except PermissionError as exc:
            app.write_diagnostic(exc)
        self.assertIn("PermissionError", app.DIAGNOSTIC_FILE.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
