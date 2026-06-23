#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/outputs/EyeRest.app"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_APP_NAME="松一下.app"
STAGING_DIR="$DIST_DIR/staging"

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "${LC_ALL:-}" == "C.UTF-8" ]] && export LC_ALL="en_US.UTF-8"
  [[ "${LC_CTYPE:-}" == "C.UTF-8" ]] && export LC_CTYPE="en_US.UTF-8"
  [[ "${LANG:-}" == "C.UTF-8" || -z "${LANG:-}" ]] && export LANG="en_US.UTF-8"
fi

"$ROOT_DIR/scripts/build_app.sh" >/dev/null

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"
ARCHIVE_NAME="songyixia-${VERSION}-${BUILD}.zip"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

rm -rf "$DIST_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/$PACKAGE_APP_NAME"

(
  cd "$STAGING_DIR"
  /usr/bin/ditto -c -k --keepParent --norsrc --noextattr "$PACKAGE_APP_NAME" "$ARCHIVE_PATH"
)

rm -rf "$STAGING_DIR"

(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$ARCHIVE_NAME" > "$(basename "$CHECKSUM_PATH")"
)

echo "$ARCHIVE_PATH"
