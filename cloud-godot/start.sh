#!/usr/bin/env bash
set -uo pipefail

node cloud-godot/health.js &
HEALTH_PID=$!
trap 'kill $HEALTH_PID 2>/dev/null || true' EXIT

GODOT_BIN=".cloud-godot/Godot_v4.7.1-stable_linux.x86_64"

# The Internet edition uses its own lightweight persistent bridge. Remove normal
# editor-plugin autostart only in this ephemeral Render copy so docks/debug UI and
# recovery-mode behaviour cannot interfere. The repository file stays unchanged.
cp project.godot /tmp/goddo-project.runtime-original
awk '
  BEGIN { skip=0 }
  /^\[editor_plugins\]$/ { skip=1; next }
  skip && /^\[/ { skip=0 }
  !skip { print }
' /tmp/goddo-project.runtime-original > project.godot

while true; do
  echo "[Goddo Cloud] Starting Godot 4.7.1 headless editor with direct MCP bootstrap..."
  "$GODOT_BIN" --headless --editor --path . --audio-driver Dummy res://cloud-godot/cloud_bootstrap.tscn
  GODOT_EXIT=$?
  echo "[Goddo Cloud] Godot exited with code ${GODOT_EXIT}. Restarting in 10s..."
  sleep 10
done
