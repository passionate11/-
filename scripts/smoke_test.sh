#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_TARGET="/Applications/松一下.app"
BINARY="$APP_TARGET/Contents/MacOS/EyeRest"
BUNDLE_ID="local.codex.eyerest"
URL_SCHEME="songyixia"

cd "$ROOT_DIR"

fail() {
  echo "smoke_test: $*" >&2
  exit 1
}

wait_for_process() {
  local attempt
  for attempt in {1..20}; do
    if pgrep -f "$BINARY" >/dev/null; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

history_contains() {
  local history token
  history="$(/usr/bin/defaults read "$BUNDLE_ID" recoveryHistory 2>/dev/null || true)"
  for token in "$@"; do
    if [[ "$history" == *"$token"* ]]; then
      return 0
    fi
  done
  return 1
}

echo "==> Installing app"
"$ROOT_DIR/scripts/install_app.sh" >/dev/null
wait_for_process || fail "app did not start"

echo "==> Checking URL scheme"
/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$APP_TARGET/Contents/Info.plist" | rg -q "$URL_SCHEME" \
  || fail "URL scheme $URL_SCHEME is not registered"

echo "==> Checking binary selectors"
strings "$BINARY" | rg -q 'handleAutomationURL:' || fail "automation URL selector missing"
strings "$BINARY" | rg -q 'runRecoveryStressTest:' || fail "recovery stress selector missing"
strings "$BINARY" | rg -q 'importBackupJSON:' || fail "backup import selector missing"

echo "==> Checking single-instance behavior"
open -n "$APP_TARGET"
sleep 1
process_count="$(pgrep -f "$BINARY" | wc -l | tr -d ' ')"
[[ "$process_count" == "1" ]] || fail "expected 1 EyeRest process, got $process_count"

echo "==> Checking settings reopen"
open -n "$APP_TARGET"
sleep 1
if [[ -x /tmp/list_windows ]]; then
  /tmp/list_windows 2>&1 | rg -q '松一下|\\U677e\\U4e00\\U4e0b' || fail "settings window was not found"
else
  echo "    /tmp/list_windows missing; skipped WindowServer check"
fi

echo "==> Checking automation URLs"
open "$URL_SCHEME://focus/on"
sleep 1
history_contains '轻打扰开启' '\\U8f7b\\U6253\\U6270\\U5f00\\U542f' || fail "focus/on did not record success"
open "$URL_SCHEME://focus/off"
sleep 1
history_contains '轻打扰关闭' '\\U8f7b\\U6253\\U6270\\U5173\\U95ed' || fail "focus/off did not record success"
open "$URL_SCHEME://pause/10s"
sleep 1
history_contains '暂停 00:10' '\\U6682\\U505c 00:10' || fail "pause/10s did not record success"
open "$URL_SCHEME://resume"
sleep 1
history_contains '继续提醒' '\\U7ee7\\U7eed\\U63d0\\U9192' || fail "resume did not record success"

echo "==> Checking recovery stress URL"
open "$URL_SCHEME://diagnostics/recovery-stress"
sleep 5
history_contains '完成 5/5' '\\U5b8c\\U6210 5/5' || fail "recovery stress did not complete"

echo "==> Smoke test passed"
