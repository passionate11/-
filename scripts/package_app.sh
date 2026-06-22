#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/outputs/EyeRest.app"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_APP_NAME="松一下.app"
STAGING_DIR="$DIST_DIR/staging"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"
ARCHIVE_NAME="songyixia-${VERSION}-${BUILD}.zip"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"

rm -rf "$DIST_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/$PACKAGE_APP_NAME"

(
  cd "$STAGING_DIR"
  /usr/bin/ditto -c -k --keepParent --norsrc --noextattr "$PACKAGE_APP_NAME" "$ARCHIVE_PATH"
)

rm -rf "$STAGING_DIR"

echo "$ARCHIVE_PATH"
