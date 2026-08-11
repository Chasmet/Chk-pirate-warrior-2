#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.7.1-stable"
ZIP="Godot_v4.7.1-stable_linux.x86_64.zip"
URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/${ZIP}"
DEST=".cloud-godot"
GODOT_BIN="$DEST/Godot_v4.7.1-stable_linux.x86_64"

mkdir -p "$DEST"
if [ ! -x "$GODOT_BIN" ]; then
  echo "[Goddo Cloud] Downloading Godot ${GODOT_VERSION}..."
  curl -L --fail --retry 3 "$URL" -o "/tmp/$ZIP"
  unzip -o "/tmp/$ZIP" -d "$DEST"
  chmod +x "$GODOT_BIN"
fi

echo "[Goddo Cloud] Godot ready. Pre-importing project cache during build..."

cp project.godot /tmp/goddo-project.godot.original
restore_project() {
  cp /tmp/goddo-project.godot.original project.godot
}
trap restore_project EXIT

# Import the heavy project once during Render's build phase, where more memory is
# available. Editor plugins are temporarily removed so the MCP relay only starts
# later in the runtime instance.
awk '
  BEGIN { skip=0 }
  /^\[editor_plugins\]$/ { skip=1; next }
  skip && /^\[/ { skip=0 }
  !skip { print }
' /tmp/goddo-project.godot.original > project.godot

set +e
timeout 300 "$GODOT_BIN" --headless --path . --import --audio-driver Dummy
IMPORT_EXIT=$?
set -e
restore_project
trap - EXIT

if [ "$IMPORT_EXIT" -ne 0 ]; then
  echo "[Goddo Cloud] Pre-import exited with code $IMPORT_EXIT."
  exit "$IMPORT_EXIT"
fi

if [ -d .godot ]; then
  echo "[Goddo Cloud] Pre-import complete. Cached .godot size: $(du -sh .godot | cut -f1)"
else
  echo "[Goddo Cloud] ERROR: Godot cache was not created."
  exit 1
fi
