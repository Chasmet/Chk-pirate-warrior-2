"""Create a clean Godot export without modifying original GLB assets."""
from pathlib import Path
import os
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "ci_export"
DEST.mkdir(exist_ok=True)
for name in ("scenes", "scripts", "data", "assets", "addons"):
    shutil.copytree(ROOT / name, DEST / name, dirs_exist_ok=True)
for name in ("project.godot", "export_presets.cfg", "default_bus_layout.tres"):
    shutil.copy2(ROOT / name, DEST / name)
for file in ROOT.glob("*.glb"):
    shutil.copy2(file, DEST / file.name)
# Editor MCP remains in the source project, but cannot run or enter an APK.
project = (DEST / "project.godot").read_text()
project = re.sub(r'enabled=PackedStringArray\([^\n]*\)', 'enabled=PackedStringArray("res://addons/chk_updater/plugin.cfg")', project)
version = "12.0." + os.environ.get("GITHUB_RUN_NUMBER", "0")
project = re.sub(r'config/version="[^"]+"', f'config/version="{version}"', project)
(DEST / "project.godot").write_text(project)
preset = (DEST / "export_presets.cfg").read_text()
preset = re.sub(r'version/code=\d+', f'version/code={1200000 + int(os.environ.get("GITHUB_RUN_NUMBER", "0"))}', preset)
preset = re.sub(r'version/name="[^"]+"', f'version/name="{version}"', preset)
(DEST / "export_presets.cfg").write_text(preset)
print(f"Export V{version} préparé")
