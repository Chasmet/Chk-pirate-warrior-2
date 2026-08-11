#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.7.1-stable"
ZIP="Godot_v4.7.1-stable_linux.x86_64.zip"
URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/${ZIP}"
DEST=".cloud-godot"

mkdir -p "$DEST"
if [ ! -x "$DEST/Godot_v4.7.1-stable_linux.x86_64" ]; then
  echo "[Goddo Cloud] Downloading Godot ${GODOT_VERSION}..."
  curl -L --fail --retry 3 "$URL" -o "/tmp/$ZIP"
  unzip -o "/tmp/$ZIP" -d "$DEST"
  chmod +x "$DEST/Godot_v4.7.1-stable_linux.x86_64"
fi

echo "[Goddo Cloud] Godot ready."
