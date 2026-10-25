import importlib.util
import io
import tempfile
import unittest
from pathlib import Path

file = Path(__file__).resolve().parents[1] / "launcher.py"
spec = importlib.util.spec_from_file_location("godot_launcher", file)
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

def executable(size=12000):
    data = bytearray(b"\0" * size)
    data[:2] = b"MZ"
    data[60:64] = (128).to_bytes(4, "little")
    data[128:132] = b"PE\0\0"
    return bytes(data)

class LauncherTests(unittest.TestCase):
    def test_copy_outside_onedrive_and_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            app = launcher.Launcher(directory)
            data = executable()
            app.import_file(io.BytesIO(data), len(data), "CHK-Godot-Installation (7).exe")
            self.assertEqual(app.exe.read_bytes(), data)
            app.import_file(io.BytesIO(data), len(data), "CHK-Godot-Installation.exe")
            self.assertTrue((Path(directory) / "version-precedente.exe").is_file())
    def test_not_arbitrary_exe(self):
        with tempfile.TemporaryDirectory() as directory:
            app = launcher.Launcher(directory)
            with self.assertRaises(ValueError):
                app.import_file(io.BytesIO(executable()), 12000, "autre.exe")
            with self.assertRaises(ValueError):
                app.import_file(io.BytesIO(b"x"*12000), 12000, "CHK-Godot-Installation.exe")
    def test_clear_offline_state(self):
        with tempfile.TemporaryDirectory() as directory:
            app = launcher.Launcher(directory)
            self.assertFalse(app.status()["installed"])
            with self.assertRaises(ValueError):
                app.start()

if __name__ == "__main__":
    unittest.main()
