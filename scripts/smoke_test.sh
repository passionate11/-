#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_TARGET="/Applications/松一下.app"
BINARY="$APP_TARGET/Contents/MacOS/EyeRest"
BUNDLE_ID="local.codex.eyerest"
URL_SCHEME="songyixia"
PREF_BACKUP="$(mktemp "${TMPDIR:-/tmp}/songyixia-smoke-prefs.XXXXXX.plist")"
HAD_PREFS=0
APP_WAS_RUNNING=0

cd "$ROOT_DIR"

fail() {
  echo "smoke_test: $*" >&2
  exit 1
}

if pgrep -f "$BINARY" >/dev/null 2>&1; then
  APP_WAS_RUNNING=1
fi

if /usr/bin/defaults export "$BUNDLE_ID" "$PREF_BACKUP" >/dev/null 2>&1; then
  HAD_PREFS=1
else
  rm -f "$PREF_BACKUP"
fi

cleanup() {
  local status="$?"
  set +e

  pkill -f "$BINARY" 2>/dev/null
  pkill -x EyeRest 2>/dev/null

  if [[ "$HAD_PREFS" == "1" && -f "$PREF_BACKUP" ]]; then
    /usr/bin/defaults import "$BUNDLE_ID" "$PREF_BACKUP" >/dev/null 2>&1
    rm -f "$PREF_BACKUP"
  else
    /usr/bin/defaults delete "$BUNDLE_ID" >/dev/null 2>&1
  fi

  if [[ "$APP_WAS_RUNNING" == "1" ]]; then
    open "$APP_TARGET" >/dev/null 2>&1
  fi

  exit "$status"
}

trap cleanup EXIT

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
open "$URL_SCHEME://rhythm/debug"
sleep 1
history_contains '快速节奏 调试 10 秒' '\\U5feb\\U901f\\U8282\\U594f \\U8c03\\U8bd5 10 \\U79d2' || fail "rhythm/debug did not record success"
[[ "$(/usr/bin/defaults read "$BUNDLE_ID" eyeFocusSeconds 2>/dev/null || true)" == "10" ]] || fail "rhythm/debug did not set eyeFocusSeconds to 10"
[[ "$(/usr/bin/defaults read "$BUNDLE_ID" eyeRestSeconds 2>/dev/null || true)" == "10" ]] || fail "rhythm/debug did not set eyeRestSeconds to 10"
open "$URL_SCHEME://automation/focus-template"
sleep 1
history_contains '已复制专注联动脚本' '\\U5df2\\U590d\\U5236\\U4e13\\U6ce8\\U8054\\U52a8\\U811a\\U672c' || fail "focus template URL did not record success"
template="$(/usr/bin/pbpaste)"
[[ "$template" == *"songyixia://focus/on"* ]] || fail "focus template missing focus/on"
[[ "$template" == *"songyixia://focus/off"* ]] || fail "focus template missing focus/off"
[[ "$template" == *"Hammerspoon"* ]] || fail "focus template missing Hammerspoon section"
[[ "$template" == *"@raycast.schemaVersion"* ]] || fail "focus template missing Raycast metadata"
[[ "$template" == *"songyixia://pause/30m"* ]] || fail "focus template missing Raycast pause command"
open "$URL_SCHEME://automation/diagnostic"
sleep 1
history_contains '已复制自动化诊断' '\\U5df2\\U590d\\U5236\\U81ea\\U52a8\\U5316\\U8bca\\U65ad' || fail "automation diagnostic URL did not record success"
automation_diagnostic="$(/usr/bin/pbpaste)"
[[ "$automation_diagnostic" == *"URL Scheme"* ]] || fail "automation diagnostic missing URL scheme"
[[ "$automation_diagnostic" == *"songyixia://focus/on"* ]] || fail "automation diagnostic missing focus/on"
[[ "$automation_diagnostic" == *"manual="* ]] || fail "automation diagnostic missing focus flags"
[[ "$automation_diagnostic" == *"local.codex.eyerest"* ]] || fail "automation diagnostic missing app bundle id"

echo "==> Checking recovery stress URL"
open "$URL_SCHEME://diagnostics/recovery-stress"
sleep 5
history_contains '完成 5/5' '\\U5b8c\\U6210 5/5' || fail "recovery stress did not complete"

echo "==> Checking lunch recovery URL"
open "$URL_SCHEME://diagnostics/lunch-recovery"
sleep 3
history_contains '完成 3/3' '\\U5b8c\\U6210 3/3' || fail "lunch recovery stress did not complete"
history_contains '站立过期已结算' '\\U7ad9\\U7acb\\U8fc7\\U671f\\U5df2\\U7ed3\\U7b97' || fail "lunch recovery did not settle expired stand rest"

echo "==> Checking sleep hidden recovery URL"
open "$URL_SCHEME://diagnostics/sleep-hidden-recovery"
sleep 3
history_contains '睡眠隐藏恢复压测' '\\U7761\\U7720\\U9690\\U85cf\\U6062\\U590d\\U538b\\U6d4b' || fail "sleep hidden recovery stress did not run"
history_contains '隐藏休息页已恢复' '\\U9690\\U85cf\\U4f11\\U606f\\U9875\\U5df2\\U6062\\U590d' || fail "sleep hidden recovery did not restore hidden rest window"
history_contains '已让开休息页保持隐藏' '\\U5df2\\U8ba9\\U5f00\\U4f11\\U606f\\U9875\\U4fdd\\U6301\\U9690\\U85cf' || fail "sleep hidden recovery did not preserve yielded rest window"
history_contains '测试状态已还原' '\\U6d4b\\U8bd5\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "sleep hidden recovery did not clean up test state"

echo "==> Checking long-away recovery URL"
open "$URL_SCHEME://diagnostics/long-away-recovery"
sleep 3
history_contains '长离开恢复压测' '\\U957f\\U79bb\\U5f00\\U6062\\U590d\\U538b\\U6d4b' || fail "long-away recovery stress did not run"
history_contains '眼睛过期已结算' '\\U773c\\U775b\\U8fc7\\U671f\\U5df2\\U7ed3\\U7b97' || fail "long-away recovery did not settle expired eye rest"
history_contains '站立过期已结算' '\\U7ad9\\U7acb\\U8fc7\\U671f\\U5df2\\U7ed3\\U7b97' || fail "long-away recovery did not settle expired stand rest"
history_contains '无休息页' '\\U65e0\\U4f11\\U606f\\U9875' || fail "long-away recovery did not clear rest window"
history_contains '统计已还原' '\\U7edf\\U8ba1\\U5df2\\U8fd8\\U539f' || fail "long-away recovery did not restore stats"

echo "==> Checking display recovery URL"
open "$URL_SCHEME://diagnostics/display-recovery"
sleep 3
history_contains '完成 3/3' '\\U5b8c\\U6210 3/3' || fail "display recovery stress did not complete"
history_contains '窗口回到屏幕内' '\\U7a97\\U53e3\\U56de\\U5230\\U5c4f\\U5e55\\U5185' || fail "display recovery did not restore window onscreen"

echo "==> Checking display bounds URL"
open "$URL_SCHEME://diagnostics/display-bounds"
sleep 3
history_contains '显示边界压测' '\\U663e\\U793a\\U8fb9\\U754c\\U538b\\U6d4b' || fail "display bounds stress did not run"
history_contains '窗口已贴合屏幕' '\\U7a97\\U53e3\\U5df2\\U8d34\\U5408\\U5c4f\\U5e55' || fail "display bounds stress did not refit window"
history_contains '内容已重排' '\\U5185\\U5bb9\\U5df2\\U91cd\\U6392' || fail "display bounds stress did not relayout content"

echo "==> Checking overlay yield URL"
open "$URL_SCHEME://diagnostics/overlay-yield"
sleep 3
history_contains '窗口让开压测' '\\U7a97\\U53e3\\U8ba9\\U5f00\\U538b\\U6d4b' || fail "overlay yield stress did not run"
history_contains '休息页已让开' '\\U4f11\\U606f\\U9875\\U5df2\\U8ba9\\U5f00' || fail "overlay yield stress did not yield rest overlay"
history_contains '设置页保留' '\\U8bbe\\U7f6e\\U9875\\U4fdd\\U7559' || fail "overlay yield stress did not preserve settings window"
history_contains '休息计时继续' '\\U4f11\\U606f\\U8ba1\\U65f6\\U7ee7\\U7eed' || fail "overlay yield stress did not keep timer running"

echo "==> Checking window layer policy URL"
open "$URL_SCHEME://diagnostics/window-layer"
sleep 4
history_contains '窗口层级压测' '\\U7a97\\U53e3\\U5c42\\U7ea7\\U538b\\U6d4b' || fail "window layer policy stress did not run"
history_contains '设置页普通层级' '\\U8bbe\\U7f6e\\U9875\\U666e\\U901a\\U5c42\\U7ea7' || fail "window layer policy did not keep settings normal"
history_contains '普通休息页未置顶' '\\U666e\\U901a\\U4f11\\U606f\\U9875\\U672a\\U7f6e\\U9876' || fail "window layer policy did not keep normal rest non-topmost"
history_contains '让开后未弹回' '\\U8ba9\\U5f00\\U540e\\U672a\\U5f39\\U56de' || fail "window layer policy did not preserve yielded rest"
history_contains '强提醒才置顶' '\\U5f3a\\U63d0\\U9192\\U624d\\U7f6e\\U9876' || fail "window layer policy did not gate topmost mode"
history_contains '测试状态已还原' '\\U6d4b\\U8bd5\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "window layer policy did not restore test state"

echo "==> Checking automation policy URL"
open "$URL_SCHEME://diagnostics/automation-policy"
sleep 4
history_contains '自动化策略压测' '\\U81ea\\U52a8\\U5316\\U7b56\\U7565\\U538b\\U6d4b' || fail "automation policy stress did not run"
history_contains '安静时段只发通知' '\\U5b89\\U9759\\U65f6\\U6bb5\\U53ea\\U53d1\\U901a\\U77e5' || fail "automation policy did not keep quiet hours notification-only"
history_contains '自动暂停命中' '\\U81ea\\U52a8\\U6682\\U505c\\U547d\\U4e2d' || fail "automation policy did not hit auto pause"
history_contains '自动暂停已关闭休息页' '\\U81ea\\U52a8\\U6682\\U505c\\U5df2\\U5173\\U95ed\\U4f11\\U606f\\U9875' || fail "automation policy did not close rest window"
history_contains '提醒时间已顺延' '\\U63d0\\U9192\\U65f6\\U95f4\\U5df2\\U987a\\U5ef6' || fail "automation policy did not shift reminder time"
history_contains '测试状态已还原' '\\U6d4b\\U8bd5\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "automation policy did not restore test state"

echo "==> Checking presentation policy URL"
open "$URL_SCHEME://diagnostics/presentation-policy"
sleep 3
history_contains '演示策略压测' '\\U6f14\\U793a\\U7b56\\U7565\\U538b\\U6d4b' || fail "presentation policy stress did not run"
history_contains '演示模式只发通知' '\\U6f14\\U793a\\U6a21\\U5f0f\\U53ea\\U53d1\\U901a\\U77e5' || fail "presentation policy did not keep notification-only"
history_contains '演示命中已关闭休息页' '\\U6f14\\U793a\\U547d\\U4e2d\\U5df2\\U5173\\U95ed\\U4f11\\U606f\\U9875' || fail "presentation policy did not close rest window"
history_contains '恢复自检不弹休息页' '\\U6062\\U590d\\U81ea\\U68c0\\U4e0d\\U5f39\\U4f11\\U606f\\U9875' || fail "presentation policy recovery check popped rest window"
history_contains '测试状态已还原' '\\U6d4b\\U8bd5\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "presentation policy did not restore test state"

echo "==> Checking calendar policy URL"
open "$URL_SCHEME://diagnostics/calendar-policy"
sleep 4
history_contains '日历策略压测' '\\U65e5\\U5386\\U7b56\\U7565\\U538b\\U6d4b' || fail "calendar policy stress did not run"
history_contains '日历会议只发通知' '\\U65e5\\U5386\\U4f1a\\U8bae\\U53ea\\U53d1\\U901a\\U77e5' || fail "calendar policy did not keep meeting notification-only"
history_contains '日程暂停命中' '\\U65e5\\U7a0b\\U6682\\U505c\\U547d\\U4e2d' || fail "calendar policy did not hit calendar auto-pause"
history_contains '日程暂停已关闭休息页' '\\U65e5\\U7a0b\\U6682\\U505c\\U5df2\\U5173\\U95ed\\U4f11\\U606f\\U9875' || fail "calendar policy did not close rest window"
history_contains '提醒时间已顺延' '\\U63d0\\U9192\\U65f6\\U95f4\\U5df2\\U987a\\U5ef6' || fail "calendar policy did not shift reminder time"
history_contains '统计已还原' '\\U7edf\\U8ba1\\U5df2\\U8fd8\\U539f' || fail "calendar policy did not restore stats"
history_contains '测试状态已还原' '\\U6d4b\\U8bd5\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "calendar policy did not restore test state"

echo "==> Checking real calendar diagnostic URL"
open "$URL_SCHEME://diagnostics/calendar-real"
sleep 1
history_contains '复制真实日历诊断' '\\U590d\\U5236\\U771f\\U5b9e\\U65e5\\U5386\\U8bca\\U65ad' || fail "calendar diagnostic URL did not record success"
calendar_diagnostic="$(/usr/bin/pbpaste)"
[[ "$calendar_diagnostic" == *"calendar="* ]] || fail "calendar diagnostic missing calendar flag"
[[ "$calendar_diagnostic" == *"calendarPause="* ]] || fail "calendar diagnostic missing calendar pause flag"
[[ "$calendar_diagnostic" == *"autoPause="* ]] || fail "calendar diagnostic missing auto pause flag"

echo "==> Checking live calendar policy URL"
open "$URL_SCHEME://diagnostics/calendar-live"
sleep 4
history_contains '真实日历联动自检' '\\U771f\\U5b9e\\U65e5\\U5386\\U8054\\U52a8\\U81ea\\U68c0' || fail "live calendar policy check did not run"
if ! history_contains '跳过' '\\U8df3\\U8fc7' '真实日历命中' '\\U771f\\U5b9e\\U65e5\\U5386\\U547d\\U4e2d' '测试状态已还原' '\\U6d4b\\U8bd5\\U72b6\\U6001\\U5df2\\U8fd8\\U539f'; then
  fail "live calendar policy check did not record skip or pass state"
fi

echo "==> Smoke test passed"
