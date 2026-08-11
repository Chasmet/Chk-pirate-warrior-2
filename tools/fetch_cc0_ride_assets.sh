#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
ASSET_DIR="$ROOT_DIR/assets/cc0_rides"
TMP_DIR="${RUNNER_TEMP:-/tmp}/chk_cc0_rides"

KENNEY_COMMIT="f5241ebdf00c25bc951bf4fdb7950bb1b78b4bcc"
KENNEY_MODEL="vehicle-truck-green.glb"
KENNEY_URL="https://raw.githubusercontent.com/KenneyNL/Starter-Kit-Racing/${KENNEY_COMMIT}/models/${KENNEY_MODEL}"
ANIMASIM_VERSION="0.2.1"
ANIMASIM_WHEEL_SHA256="d111ffc9782f09872846b09ac7868d41e126ef72e3153d9d0173d401be3277a3"

rm -rf "$TMP_DIR"
mkdir -p "$ASSET_DIR" "$TMP_DIR"

printf '%s\n' '=== CC0 rides: Kenney 4x4 ==='
curl --fail --location --retry 3 --retry-delay 2 \
  "$KENNEY_URL" \
  --output "$ASSET_DIR/4x4_kenney.glb"

printf '%s\n' '=== CC0 rides: Quaternius horse via AnimaSim redistribution ==='
python3 -m pip download \
  --disable-pip-version-check \
  --no-deps \
  --only-binary=:all: \
  "animasim==${ANIMASIM_VERSION}" \
  --dest "$TMP_DIR"

WHEEL_PATH="$(find "$TMP_DIR" -maxdepth 1 -type f -name "animasim-${ANIMASIM_VERSION}-py3-none-any.whl" -print -quit)"
if [ -z "$WHEEL_PATH" ]; then
  echo 'ERREUR: wheel AnimaSim introuvable.' >&2
  exit 20
fi

echo "${ANIMASIM_WHEEL_SHA256}  ${WHEEL_PATH}" | sha256sum -c -
mkdir -p "$TMP_DIR/wheel"
unzip -q "$WHEEL_PATH" -d "$TMP_DIR/wheel"

HORSE_PATH="$(find "$TMP_DIR/wheel" -type f -iname '*horse*.glb' -print | sort | head -n 1)"
if [ -z "$HORSE_PATH" ]; then
  echo 'ERREUR: aucun cheval GLB trouvé dans AnimaSim.' >&2
  find "$TMP_DIR/wheel" -type f | sed -n '1,120p' >&2
  exit 21
fi
cp "$HORSE_PATH" "$ASSET_DIR/horse_quaternius.glb"

python3 - "$ASSET_DIR/4x4_kenney.glb" "$ASSET_DIR/horse_quaternius.glb" <<'PY'
from pathlib import Path
import sys

for raw in sys.argv[1:]:
    path = Path(raw)
    data = path.read_bytes()
    if len(data) < 32 or data[:4] != b'glTF':
        raise SystemExit(f"GLB invalide: {path}")
    print(f"OK {path.name}: {len(data) / 1024:.1f} KiB")
PY

sha256sum "$ASSET_DIR/4x4_kenney.glb" "$ASSET_DIR/horse_quaternius.glb" \
  | tee "$ASSET_DIR/FETCHED_SHA256.txt"

printf '%s\n' 'Assets CC0 prêts pour import Godot.'
