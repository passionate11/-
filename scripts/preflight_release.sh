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
  if [[ "$haystack" != *"$needle"* ]]; then
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
URL_TYPES="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$INFO_PLIST")"
[[ "$URL_TYPES" == *"songyixia"* ]] || fail "URL scheme missing"

echo "==> Verifying binary entry points"
STRINGS_OUTPUT="$(strings "$BINARY")"
for selector in handleAutomationURL: runRecoveryStressTest: importBackupJSON: showAbout: openIssueFeedback: checkForUpdates: applyQuickRhythm: applyQuickRhythmToken: copyApplicationDiagnostic: applicationDiagnosticText toggleRestWindowTopmost:; do
  check_contains "$STRINGS_OUTPUT" "$selector" "selector"
done
check_contains "$STRINGS_OUTPUT" "https://github.com/passionate11/-" "GitHub URL"
check_contains "$STRINGS_OUTPUT" "https://github.com/passionate11/-/issues/new" "GitHub issue URL"
check_contains "$STRINGS_OUTPUT" "https://github.com/passionate11/-/releases/latest" "latest release URL"
check_contains "$STRINGS_OUTPUT" "https://api.github.com/repos/passionate11/-/releases/latest" "latest release API URL"

echo "==> Verifying window behavior guardrails"
SOURCE_CONTENT="$(< "$SOURCE_FILE")"
README_CONTENT="$(< README.md)"
check_contains "$SOURCE_CONTENT" "应用诊断" "application diagnostics title"
check_contains "$SOURCE_CONTENT" "applyQuickRhythm:" "quick rhythm action"
check_contains "$SOURCE_CONTENT" "quickRhythmMatchesItemInfo" "quick rhythm state guard"
check_contains "$SOURCE_CONTENT" "快速节奏" "quick rhythm menu"
check_contains "$SOURCE_CONTENT" "调试 10 秒" "debug rhythm menu item"
check_contains "$SOURCE_CONTENT" "rhythm/debug" "debug rhythm automation URL"
check_contains "$README_CONTENT" "songyixia://rhythm/debug" "debug rhythm docs"
check_contains "$SOURCE_CONTENT" "runLunchRecoveryStressTest:" "lunch recovery stress action"
check_contains "$SOURCE_CONTENT" "diagnostics/lunch-recovery" "lunch recovery automation URL"
check_contains "$README_CONTENT" "songyixia://diagnostics/lunch-recovery" "lunch recovery docs"
check_contains "$SOURCE_CONTENT" "午休恢复压测" "lunch recovery diagnostics"
check_contains "$SOURCE_CONTENT" "runDisplayRecoveryStressTest:" "display recovery stress action"
check_contains "$SOURCE_CONTENT" "diagnostics/display-recovery" "display recovery automation URL"
check_contains "$README_CONTENT" "songyixia://diagnostics/display-recovery" "display recovery docs"
check_contains "$SOURCE_CONTENT" "显示恢复压测" "display recovery diagnostics"
check_contains "$SOURCE_CONTENT" "反馈问题" "issue feedback menu"
check_contains "$SOURCE_CONTENT" "NSURLComponents" "issue URL builder"
check_contains "$SOURCE_CONTENT" "NSURLSession" "update check network request"
check_contains "$SOURCE_CONTENT" "ERCompareVersionStrings" "version comparison helper"
check_contains "$SOURCE_CONTENT" "ERSettingsRestWindowTopmostKey: @NO" "rest window topmost default"
check_contains "$SOURCE_CONTENT" "置顶强提醒" "topmost reminder setting"
check_contains "$SOURCE_CONTENT" "restOverlayYielded" "yielded rest overlay state"
check_contains "$SOURCE_CONTENT" "yieldRestOverlayForUserFocusChange" "rest overlay yield helper"
check_contains "$SOURCE_CONTENT" "窗口让开" "rest overlay yield diagnostic"
[[ "$SOURCE_CONTENT" == *"@interface ERSettingsWindow : NSWindow"* ]] || fail "settings window must remain a normal NSWindow"
[[ "$SOURCE_CONTENT" == *"window.level = NSNormalWindowLevel;"* ]] || fail "settings window must use NSNormalWindowLevel"
if [[ "$SOURCE_CONTENT" =~ NSFloatingWindowLevel|floatingPanel|NSWindowStyleMaskUtilityWindow|@interface\ ERSettingsPanel\ :\ NSPanel ]]; then
  fail "settings window floating-panel regression detected"
fi
REST_PRESENT_BLOCK="$(awk '/- \(void\)presentOverlay /{inside=1} inside && /^}/ {print; exit} inside{print}' "$SOURCE_FILE")"
check_contains "$REST_PRESENT_BLOCK" "if (self.appDelegate.settings.restWindowTopmost)" "rest overlay topmost gate"
check_contains "$REST_PRESENT_BLOCK" "[self.window orderFront:nil];" "rest overlay non-topmost presentation"
if [[ "$REST_PRESENT_BLOCK" != *"restWindowTopmost"* || "$REST_PRESENT_BLOCK" == *"[self.window orderFrontRegardless];"* && "$REST_PRESENT_BLOCK" != *"if (self.appDelegate.settings.restWindowTopmost)"* ]]; then
  fail "rest overlay orderFrontRegardless must stay gated by restWindowTopmost"
fi
REST_INIT_BLOCK="$(awk '/- \(instancetype\)initWithAppDelegate:/{inside=1} inside && /return self;/{print; exit} inside{print}' "$SOURCE_FILE")"
check_contains "$REST_INIT_BLOCK" "window.collectionBehavior = NSWindowCollectionBehaviorManaged;" "rest overlay default collection behavior"
if [[ "$REST_INIT_BLOCK" == *"NSWindowCollectionBehaviorCanJoinAllSpaces"* || "$REST_INIT_BLOCK" == *"NSWindowCollectionBehaviorFullScreenAuxiliary"* ]]; then
  fail "rest overlay must not join all spaces by default"
fi
SETTINGS_PRESENT_BLOCK="$(awk '/- \(void\)presentSettingsWindow /{inside=1} inside && /}/{print; exit} inside{print}' "$SOURCE_FILE")"
if [[ "$SETTINGS_PRESENT_BLOCK" == *"orderFrontRegardless"* ]]; then
  fail "settings window must not use orderFrontRegardless"
fi

echo "==> Verifying signature and diagnostics"
codesign --verify --deep --strict "$APP_BUNDLE"
CODESIGN_DETAILS="$(codesign -dv "$APP_BUNDLE" 2>&1 || true)"
[[ "$CODESIGN_DETAILS" == *"Signature=adhoc"* ]] || fail "expected ad-hoc signature"
DIAGNOSE_OUTPUT="$(APP_TARGET="$APP_BUNDLE" scripts/diagnose_app.sh)"
[[ "$DIAGNOSE_OUTPUT" =~ codesign[[:space:]]verify:[[:space:]]+ok ]] || fail "diagnostics did not confirm signature"

echo "==> Verifying changelog"
grep -q "## $EXPECTED_VERSION" CHANGELOG.md || fail "CHANGELOG.md missing $EXPECTED_VERSION section"

echo "==> Packaging app"
ARCHIVE="$(scripts/package_app.sh)"
[[ -s "$ARCHIVE" ]] || fail "archive was not created"
ZIP_LIST="$(unzip -l "$ARCHIVE")"
[[ "$ZIP_LIST" == *"Contents/MacOS/EyeRest"* ]] || fail "archive missing executable"
[[ "$ZIP_LIST" == *"Contents/Resources/AppIcon.icns"* ]] || fail "archive missing icon"
if [[ "$ZIP_LIST" == *"/._"* ]]; then
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
[[ "$PACKAGED_DIAGNOSE_OUTPUT" =~ codesign[[:space:]]verify:[[:space:]]+ok ]] || fail "packaged app diagnostics failed"

echo "==> Preflight passed: $ARCHIVE"
