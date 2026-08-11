#!/usr/bin/env bash
set -uo pipefail

export GODOT_MCP_PORT="${GODOT_MCP_PORT:-9080}"
export GODOT_MCP_HTTP_PORT="${GODOT_MCP_HTTP_PORT:-9100}"

node cloud-godot/health.js &
HEALTH_PID=$!
trap 'kill $HEALTH_PID 2>/dev/null || true' EXIT

GODOT_BIN=".cloud-godot/Godot_v4.7.1-stable_linux.x86_64"

while true; do
  echo "[Goddo Cloud] Starting Godot 4.7.1 headless editor..."
  "$GODOT_BIN" --headless --editor --path . --audio-driver Dummy --verbose
  GODOT_EXIT=$?
  echo "[Goddo Cloud] Godot exited with code ${GODOT_EXIT}. Restarting in 10s..."
  sleep 10
done
