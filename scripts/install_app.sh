#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SOURCE="$ROOT_DIR/outputs/EyeRest.app"
APP_TARGET="/Applications/松一下.app"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null

pkill -f "$APP_TARGET/Contents/MacOS/EyeRest" 2>/dev/null || true
pkill -x EyeRest 2>/dev/null || true

rm -rf "$APP_TARGET"
cp -R "$APP_SOURCE" "$APP_TARGET"
open "$APP_TARGET"

echo "$APP_TARGET"
