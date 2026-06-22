#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/outputs/EyeRest.app"
BINARY="$APP_BUNDLE/Contents/MacOS/EyeRest"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
EXPECTED_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
SOURCE_FILE="$ROOT_DIR/Sources/EyeRestObjC/main.m"

cd "$ROOT_DIR"

fail() {
  echo "preflight_release: $*" >&2
  exit 1
}

check_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if ! printf '%s\n' "$haystack" | grep -Fq "$needle"; then
    fail "$label missing: $needle"
  fi
}

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST"
}

echo "==> Checking shell scripts"
bash -n scripts/build_app.sh
bash -n scripts/diagnose_app.sh
bash -n scripts/generate_icon.sh
bash -n scripts/install_app.sh
bash -n scripts/package_app.sh
bash -n scripts/preflight_release.sh
bash -n scripts/smoke_test.sh

echo "==> Building app"
scripts/build_app.sh >/dev/null

echo "==> Verifying bundle metadata"
[[ -x "$BINARY" ]] || fail "binary is missing or not executable"
[[ -s "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]] || fail "AppIcon.icns is missing"
[[ "$(plist_value CFBundleIdentifier)" == "local.codex.eyerest" ]] || fail "bundle identifier mismatch"
[[ "$(plist_value CFBundleDisplayName)" == "松一下" ]] || fail "display name mismatch"
[[ "$(plist_value CFBundleIconFile)" == "AppIcon" ]] || fail "icon metadata mismatch"
[[ "$(plist_value CFBundleShortVersionString)" == "$EXPECTED_VERSION" ]] || fail "version mismatch"
/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$INFO_PLIST" | grep -q 'songyixia' || fail "URL scheme missing"

echo "==> Verifying binary entry points"
STRINGS_OUTPUT="$(strings "$BINARY")"
for selector in handleAutomationURL: runRecoveryStressTest: importBackupJSON: showAbout:; do
  check_contains "$STRINGS_OUTPUT" "$selector" "selector"
done
check_contains "$STRINGS_OUTPUT" "https://github.com/passionate11/-" "GitHub URL"

echo "==> Verifying window behavior guardrails"
grep -q '@interface ERSettingsWindow : NSWindow' "$SOURCE_FILE" || fail "settings window must remain a normal NSWindow"
grep -q 'window.level = NSNormalWindowLevel;' "$SOURCE_FILE" || fail "settings window must use NSNormalWindowLevel"
if grep -Eq 'NSFloatingWindowLevel|floatingPanel|NSWindowStyleMaskUtilityWindow|@interface ERSettingsPanel : NSPanel' "$SOURCE_FILE"; then
  fail "settings window floating-panel regression detected"
fi
if awk '/- \(void\)presentSettingsWindow /{inside=1} inside && /}/{print; exit} inside{print}' "$SOURCE_FILE" | grep -q 'orderFrontRegardless'; then
  fail "settings window must not use orderFrontRegardless"
fi

echo "==> Verifying signature and diagnostics"
codesign --verify --deep --strict "$APP_BUNDLE"
CODESIGN_DETAILS="$(codesign -dv "$APP_BUNDLE" 2>&1 || true)"
printf '%s\n' "$CODESIGN_DETAILS" | grep -q 'Signature=adhoc' || fail "expected ad-hoc signature"
DIAGNOSE_OUTPUT="$(APP_TARGET="$APP_BUNDLE" scripts/diagnose_app.sh)"
printf '%s\n' "$DIAGNOSE_OUTPUT" | grep -Eq 'codesign verify:[[:space:]]+ok' || fail "diagnostics did not confirm signature"

echo "==> Verifying changelog"
grep -q "## $EXPECTED_VERSION" CHANGELOG.md || fail "CHANGELOG.md missing $EXPECTED_VERSION section"

echo "==> Packaging app"
ARCHIVE="$(scripts/package_app.sh)"
[[ -s "$ARCHIVE" ]] || fail "archive was not created"
ZIP_LIST="$(unzip -l "$ARCHIVE")"
printf '%s\n' "$ZIP_LIST" | grep -q 'Contents/MacOS/EyeRest' || fail "archive missing executable"
printf '%s\n' "$ZIP_LIST" | grep -q 'Contents/Resources/AppIcon.icns' || fail "archive missing icon"
if printf '%s\n' "$ZIP_LIST" | grep -q '/._'; then
  fail "archive contains AppleDouble resource files"
fi

echo "==> Verifying packaged app"
TMPDIR_RELEASE="$(mktemp -d "${TMPDIR:-/tmp}/songyixia-release.XXXXXX")"
cleanup() {
  rm -rf "$TMPDIR_RELEASE"
}
trap cleanup EXIT
ditto -x -k "$ARCHIVE" "$TMPDIR_RELEASE"
codesign --verify --deep --strict "$TMPDIR_RELEASE/松一下.app"
PACKAGED_DIAGNOSE_OUTPUT="$(APP_TARGET="$TMPDIR_RELEASE/松一下.app" scripts/diagnose_app.sh)"
printf '%s\n' "$PACKAGED_DIAGNOSE_OUTPUT" | grep -Eq 'codesign verify:[[:space:]]+ok' || fail "packaged app diagnostics failed"

echo "==> Preflight passed: $ARCHIVE"
