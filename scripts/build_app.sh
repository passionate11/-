#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="EyeRest"
APP_DIR="$ROOT_DIR/outputs/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
SKIP_CODESIGN="${SKIP_CODESIGN:-0}"
LOCK_PATH="$ROOT_DIR/.build/build_app.lock"

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build"

if [[ "${ER_BUILD_LOCK_HELD:-0}" != "1" ]]; then
  if command -v lockf >/dev/null 2>&1; then
    exec lockf "$LOCK_PATH" env ER_BUILD_LOCK_HELD=1 "$ROOT_DIR/scripts/build_app.sh" "$@"
  elif command -v flock >/dev/null 2>&1; then
    exec env ER_BUILD_LOCK_HELD=1 flock "$LOCK_PATH" "$ROOT_DIR/scripts/build_app.sh" "$@"
  else
    echo "warning: no lockf/flock found; concurrent builds may conflict" >&2
  fi
fi

clang -fobjc-arc \
  -mmacosx-version-min=13.0 \
  -framework Cocoa \
  -framework EventKit \
  -framework Carbon \
  -framework QuartzCore \
  -framework UserNotifications \
  -framework UniformTypeIdentifiers \
  "Sources/EyeRestObjC/main.m" \
  -o "$ROOT_DIR/.build/EyeRest"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/EyeRest" "$MACOS_DIR/$APP_NAME"
"$ROOT_DIR/scripts/generate_icon.sh" "$RESOURCES_DIR/AppIcon.icns" >/dev/null

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>EyeRest</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.eyerest</string>
  <key>CFBundleName</key>
  <string>松一下</string>
  <key>CFBundleDisplayName</key>
  <string>松一下</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>__VERSION__</string>
  <key>CFBundleVersion</key>
  <string>__BUILD_NUMBER__</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>local.codex.eyerest.automation</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>songyixia</string>
      </array>
    </dict>
  </array>
  <key>NSUserNotificationAlertStyle</key>
  <string>alert</string>
  <key>NSCalendarsUsageDescription</key>
  <string>松一下会读取当前日历事件，用于会议期间自动降低休息提醒打扰。</string>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>松一下会读取当前日历事件，用于会议期间自动降低休息提醒打扰。</string>
</dict>
</plist>
PLIST

/usr/bin/sed -i '' \
  -e "s/__VERSION__/$VERSION/g" \
  -e "s/__BUILD_NUMBER__/$BUILD_NUMBER/g" \
  "$CONTENTS_DIR/Info.plist"

if [[ "$SKIP_CODESIGN" != "1" ]]; then
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_DIR" >/dev/null
  else
    echo "warning: codesign not found; app bundle was left unsigned" >&2
  fi
fi

echo "$APP_DIR"
