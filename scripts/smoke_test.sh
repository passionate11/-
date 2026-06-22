#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_TARGET="/Applications/松一下.app"
BINARY="$APP_TARGET/Contents/MacOS/EyeRest"
BUNDLE_ID="local.codex.eyerest"
URL_SCHEME="songyixia"
PREF_BACKUP="$(mktemp "${TMPDIR:-/tmp}/songyixia-smoke-prefs.XXXXXXXX.plist")"
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

wait_for_no_process() {
  local attempt
  for attempt in {1..20}; do
    if ! pgrep -f "$BINARY" >/dev/null && ! pgrep -x EyeRest >/dev/null; then
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

wait_for_history() {
  local attempt
  for attempt in {1..20}; do
    if history_contains "$@"; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

settings_window_visible() {
  [[ -x /tmp/list_windows ]] || return 2
  /tmp/list_windows 2>&1 | awk '
    function reset_window() {
      owner = 0
      title = 0
      onscreen = 0
      normal_layer = 0
    }
    function matched() {
      return owner && title && onscreen && normal_layer
    }
    /^[0-9]{4}-[0-9]{2}-[0-9]{2} .*[{]$/ {
      if (matched()) found = 1
      reset_window()
    }
    /kCGWindowOwnerName/ && ($0 ~ /松一下/ || $0 ~ /\\U677e\\U4e00\\U4e0b/) { owner = 1 }
    /kCGWindowName/ && ($0 ~ /设置/ || $0 ~ /\\U8bbe\\U7f6e/) { title = 1 }
    /kCGWindowIsOnscreen = 1/ { onscreen = 1 }
    /kCGWindowLayer = 0/ { normal_layer = 1 }
    END {
      if (matched()) found = 1
      exit(found ? 0 : 1)
    }
  '
}

echo "==> Installing app"
"$ROOT_DIR/scripts/install_app.sh" >/dev/null
/usr/bin/defaults write "$BUNDLE_ID" quickSetupSeen -bool true
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
  settings_window_visible || fail "settings window was not visible"
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
open "$URL_SCHEME://settings/eye"
sleep 1
history_contains '打开设置 eye' '\\U6253\\U5f00\\U8bbe\\U7f6e eye' || fail "settings/eye did not record success"
if [[ -x /tmp/list_windows ]]; then
  settings_window_visible || fail "settings/eye did not show settings window"
fi
open "$URL_SCHEME://settings/stand"
sleep 1
history_contains '打开设置 stand' '\\U6253\\U5f00\\U8bbe\\U7f6e stand' || fail "settings/stand did not record success"
if [[ -x /tmp/list_windows ]]; then
  settings_window_visible || fail "settings/stand did not show settings window"
fi
open "$URL_SCHEME://rhythm/debug"
sleep 1
history_contains '快速节奏 调试 10 秒' '\\U5feb\\U901f\\U8282\\U594f \\U8c03\\U8bd5 10 \\U79d2' || fail "rhythm/debug did not record success"
[[ "$(/usr/bin/defaults read "$BUNDLE_ID" eyeFocusSeconds 2>/dev/null || true)" == "10" ]] || fail "rhythm/debug did not set eyeFocusSeconds to 10"
[[ "$(/usr/bin/defaults read "$BUNDLE_ID" eyeRestSeconds 2>/dev/null || true)" == "10" ]] || fail "rhythm/debug did not set eyeRestSeconds to 10"
open "$URL_SCHEME://setup/stand"
sleep 1
history_contains '已应用 久坐打断' '\\U5df2\\U5e94\\U7528 \\U4e45\\U5750\\U6253\\U65ad' || fail "setup/stand did not record success"
[[ "$(/usr/bin/defaults read "$BUNDLE_ID" standIntervalSeconds 2>/dev/null || true)" == "3600" ]] || fail "setup/stand did not set standIntervalSeconds to 3600"
[[ "$(/usr/bin/defaults read "$BUNDLE_ID" standDurationSeconds 2>/dev/null || true)" == "600" ]] || fail "setup/stand did not set standDurationSeconds to 600"
[[ "$(/usr/bin/defaults read "$BUNDLE_ID" restWindowTopmost 2>/dev/null || true)" == "0" ]] || fail "setup/stand should keep restWindowTopmost disabled"
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
history_contains '已模拟休息页按钮链路异常' '\\U5df2\\U6a21\\U62df\\U4f11\\U606f\\U9875\\U6309\\U94ae\\U94fe\\U8def\\U5f02\\U5e38' || fail "recovery stress did not simulate broken action bindings"
history_contains '按钮链路已修复' '\\U6309\\U94ae\\U94fe\\U8def\\U5df2\\U4fee\\U590d' || fail "recovery stress did not repair broken action bindings"
history_contains '恢复压测状态已还原' '\\U6062\\U590d\\U538b\\U6d4b\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "recovery stress did not restore diagnostic rest state"

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

echo "==> Checking settings window recovery URL"
open "$URL_SCHEME://diagnostics/settings-window"
sleep 3
history_contains '设置窗口恢复压测' '\\U8bbe\\U7f6e\\U7a97\\U53e3\\U6062\\U590d\\U538b\\U6d4b' || fail "settings window recovery stress did not run"
history_contains '设置页回到屏幕内' '\\U8bbe\\U7f6e\\U9875\\U56de\\U5230\\U5c4f\\U5e55\\U5185' || fail "settings window recovery did not restore onscreen"
history_contains '设置页可见' '\\U8bbe\\U7f6e\\U9875\\U53ef\\U89c1' || fail "settings window recovery did not keep settings visible"

echo "==> Checking display bounds URL"
open "$URL_SCHEME://diagnostics/display-bounds"
sleep 3
history_contains '显示边界压测' '\\U663e\\U793a\\U8fb9\\U754c\\U538b\\U6d4b' || fail "display bounds stress did not run"
history_contains '窗口已贴合屏幕' '\\U7a97\\U53e3\\U5df2\\U8d34\\U5408\\U5c4f\\U5e55' || fail "display bounds stress did not refit window"
history_contains '内容已重排' '\\U5185\\U5bb9\\U5df2\\U91cd\\U6392' || fail "display bounds stress did not relayout content"

echo "==> Checking display change trace URL"
open "$URL_SCHEME://diagnostics/display-change-trace"
sleep 1
history_contains '显示变化追踪自检' '\\U663e\\U793a\\U53d8\\U5316\\U8ffd\\U8e2a\\U81ea\\U68c0' || fail "display change trace did not run"
history_contains '已记录屏幕变化' '\\U5df2\\U8bb0\\U5f55\\U5c4f\\U5e55\\U53d8\\U5316' || fail "display change trace did not record transition"

echo "==> Checking display diagnostic URL"
open "$URL_SCHEME://diagnostics/display-real"
sleep 1
history_contains '已复制显示环境诊断' '\\U5df2\\U590d\\U5236\\U663e\\U793a\\U73af\\U5883\\U8bca\\U65ad' || fail "display diagnostic URL did not record success"
display_diagnostic="$(/usr/bin/pbpaste)"
[[ "$display_diagnostic" == *"displayDiagnostic=1"* ]] || fail "display diagnostic missing marker"
[[ "$display_diagnostic" == *"screenCount="* ]] || fail "display diagnostic missing screen count"
[[ "$display_diagnostic" == *"displayChangeFrom="* ]] || fail "display diagnostic missing display change source"
[[ "$display_diagnostic" == *"displayChangeTo="* ]] || fail "display diagnostic missing display change target"
[[ "$display_diagnostic" == *"restWindow="* ]] || fail "display diagnostic missing rest window state"
[[ "$display_diagnostic" == *"settingsWindow="* ]] || fail "display diagnostic missing settings window state"

echo "==> Checking issue bundle diagnostic URL"
open "$URL_SCHEME://diagnostics/issue-bundle"
sleep 1
history_contains '已复制问题反馈包' '\\U5df2\\U590d\\U5236\\U95ee\\U9898\\U53cd\\U9988\\U5305' || fail "issue bundle URL did not record success"
issue_bundle="$(/usr/bin/pbpaste)"
[[ "$issue_bundle" == *"issueBundle=1"* ]] || fail "issue bundle missing marker"
[[ "$issue_bundle" == *"issueTemplate=1"* ]] || fail "issue bundle missing issue template marker"
[[ "$issue_bundle" == *"section=issue-template"* ]] || fail "issue bundle missing issue template section"
[[ "$issue_bundle" == *"recoveryReport=1"* ]] || fail "issue bundle missing recovery report"
[[ "$issue_bundle" == *"supportBundle=1"* ]] || fail "issue bundle missing support bundle"
[[ "$issue_bundle" == *"section=recovery-report"* ]] || fail "issue bundle missing recovery report section"
[[ "$issue_bundle" == *"section=support-bundle"* ]] || fail "issue bundle missing support bundle section"

echo "==> Checking support bundle diagnostic URL"
open "$URL_SCHEME://diagnostics/support-bundle"
sleep 1
history_contains '已复制完整排查包' '\\U5df2\\U590d\\U5236\\U5b8c\\U6574\\U6392\\U67e5\\U5305' || fail "support bundle URL did not record success"
support_bundle="$(/usr/bin/pbpaste)"
[[ "$support_bundle" == *"supportBundle=1"* ]] || fail "support bundle missing marker"
[[ "$support_bundle" == *"section=application"* ]] || fail "support bundle missing application section"
[[ "$support_bundle" == *"section=recovery"* ]] || fail "support bundle missing recovery section"
[[ "$support_bundle" == *"section=display"* ]] || fail "support bundle missing display section"
[[ "$support_bundle" == *"section=recovery-matrix"* ]] || fail "support bundle missing recovery matrix section"
[[ "$support_bundle" == *"section=recovery-report"* ]] || fail "support bundle missing recovery report section"
[[ "$support_bundle" == *"section=automation"* ]] || fail "support bundle missing automation section"
[[ "$support_bundle" == *"section=calendar"* ]] || fail "support bundle missing calendar section"

echo "==> Checking recovery matrix diagnostic URL"
open "$URL_SCHEME://diagnostics/recovery-matrix"
sleep 1
history_contains '已复制恢复场景矩阵' '\\U5df2\\U590d\\U5236\\U6062\\U590d\\U573a\\U666f\\U77e9\\U9635' || fail "recovery matrix URL did not record success"
recovery_matrix="$(/usr/bin/pbpaste)"
[[ "$recovery_matrix" == *"recoveryMatrix=1"* ]] || fail "recovery matrix missing marker"
[[ "$recovery_matrix" == *"scenario=base-window"* ]] || fail "recovery matrix missing base window scenario"
[[ "$recovery_matrix" == *"scenario=sleep-hidden"* ]] || fail "recovery matrix missing sleep hidden scenario"
[[ "$recovery_matrix" == *"scenario=long-away"* ]] || fail "recovery matrix missing long-away scenario"
[[ "$recovery_matrix" == *"scenario=display-offscreen"* ]] || fail "recovery matrix missing display offscreen scenario"
[[ "$recovery_matrix" == *"scenario=settings-offscreen"* ]] || fail "recovery matrix missing settings offscreen scenario"
[[ "$recovery_matrix" == *"scenario=window-layer"* ]] || fail "recovery matrix missing window layer scenario"
[[ "$recovery_matrix" == *"$URL_SCHEME://diagnostics/window-layer"* ]] || fail "recovery matrix missing window layer URL"
[[ "$recovery_matrix" == *"$URL_SCHEME://diagnostics/recovery-matrix-suite"* ]] || fail "recovery matrix missing suite URL"

echo "==> Checking recovery report diagnostic URL"
open "$URL_SCHEME://diagnostics/recovery-report"
sleep 1
history_contains '已复制恢复问题报告' '\\U5df2\\U590d\\U5236\\U6062\\U590d\\U95ee\\U9898\\U62a5\\U544a' || fail "recovery report URL did not record success"
recovery_report="$(/usr/bin/pbpaste)"
[[ "$recovery_report" == *"recoveryReport=1"* ]] || fail "recovery report missing marker"
[[ "$recovery_report" == *"summary="* ]] || fail "recovery report missing summary"
[[ "$recovery_report" == *"coverage="* ]] || fail "recovery report missing coverage marker"
[[ "$recovery_report" == *"recordedScenarios="* ]] || fail "recovery report missing recorded scenarios"
[[ "$recovery_report" == *"missingScenarios="* ]] || fail "recovery report missing missing scenarios"
[[ "$recovery_report" == *"suggestionCount="* ]] || fail "recovery report missing suggestion count"
[[ "$recovery_report" == *"$URL_SCHEME://diagnostics/recovery-matrix-suite"* ]] || fail "recovery report missing suite URL"

echo "==> Checking recovery matrix suite URL"
open "$URL_SCHEME://diagnostics/recovery-matrix-suite"
sleep 58
history_contains '恢复矩阵套件' '\\U6062\\U590d\\U77e9\\U9635\\U5957\\U4ef6' || fail "recovery matrix suite did not run"
history_contains '开始 9 个场景顺序压测' '\\U5f00\\U59cb 9 \\U4e2a\\U573a\\U666f\\U987a\\U5e8f\\U538b\\U6d4b' || fail "recovery matrix suite did not record start"
history_contains '完成 9/9' '\\U5b8c\\U6210 9/9' || fail "recovery matrix suite did not record completion"
history_contains '运行 9/9' '\\U8fd0\\U884c 9/9' || fail "recovery matrix suite did not reach final step"
history_contains '睡眠隐藏恢复压测' '\\U7761\\U7720\\U9690\\U85cf\\U6062\\U590d\\U538b\\U6d4b' || fail "recovery matrix suite did not include sleep hidden stress"
history_contains '窗口层级压测' '\\U7a97\\U53e3\\U5c42\\U7ea7\\U538b\\U6d4b' || fail "recovery matrix suite did not include window layer stress"

echo "==> Resetting recovery history for isolated policy checks"
pkill -f "$BINARY" 2>/dev/null || true
pkill -x EyeRest 2>/dev/null || true
wait_for_no_process || fail "app did not stop before recovery history reset"
/usr/bin/defaults delete "$BUNDLE_ID" recoveryHistory >/dev/null 2>&1 || true
if /usr/bin/defaults read "$BUNDLE_ID" recoveryHistory >/dev/null 2>&1; then
  fail "recovery history was not cleared before isolated policy checks"
fi
open "$APP_TARGET"
wait_for_process || fail "app did not restart after recovery history reset"

echo "==> Checking live display URL"
open "$URL_SCHEME://diagnostics/display-live"
wait_for_history '真实显示状态已还原' '\\U771f\\U5b9e\\U663e\\U793a\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "live display check did not restore state"
history_contains '真实显示环境自检' '\\U771f\\U5b9e\\U663e\\U793a\\U73af\\U5883\\U81ea\\U68c0' || fail "live display check did not run"
history_contains '真实窗口在屏幕内' '\\U771f\\U5b9e\\U7a97\\U53e3\\U5728\\U5c4f\\U5e55\\U5185' || fail "live display check did not keep window onscreen"
history_contains '真实窗口贴合屏幕' '\\U771f\\U5b9e\\U7a97\\U53e3\\U8d34\\U5408\\U5c4f\\U5e55' || fail "live display check did not fit screen"
history_contains '真实内容已重排' '\\U771f\\U5b9e\\U5185\\U5bb9\\U5df2\\U91cd\\U6392' || fail "live display check did not relayout content"

echo "==> Checking overlay yield URL"
open "$URL_SCHEME://diagnostics/overlay-yield"
wait_for_history '窗口让开状态已还原' '\\U7a97\\U53e3\\U8ba9\\U5f00\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "overlay yield stress did not restore test state"
history_contains '窗口让开压测' '\\U7a97\\U53e3\\U8ba9\\U5f00\\U538b\\U6d4b' || fail "overlay yield stress did not run"
history_contains '休息页已让开' '\\U4f11\\U606f\\U9875\\U5df2\\U8ba9\\U5f00' || fail "overlay yield stress did not yield rest overlay"
history_contains '设置页保留' '\\U8bbe\\U7f6e\\U9875\\U4fdd\\U7559' || fail "overlay yield stress did not preserve settings window"
history_contains '休息计时继续' '\\U4f11\\U606f\\U8ba1\\U65f6\\U7ee7\\U7eed' || fail "overlay yield stress did not keep timer running"

echo "==> Checking window layer policy URL"
open "$URL_SCHEME://diagnostics/window-layer"
wait_for_history '窗口层级状态已还原' '\\U7a97\\U53e3\\U5c42\\U7ea7\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "window layer policy did not restore test state"
history_contains '窗口层级压测' '\\U7a97\\U53e3\\U5c42\\U7ea7\\U538b\\U6d4b' || fail "window layer policy stress did not run"
history_contains '设置页普通层级' '\\U8bbe\\U7f6e\\U9875\\U666e\\U901a\\U5c42\\U7ea7' || fail "window layer policy did not keep settings normal"
history_contains '普通休息页未置顶' '\\U666e\\U901a\\U4f11\\U606f\\U9875\\U672a\\U7f6e\\U9876' || fail "window layer policy did not keep normal rest non-topmost"
history_contains '让开后未弹回' '\\U8ba9\\U5f00\\U540e\\U672a\\U5f39\\U56de' || fail "window layer policy did not preserve yielded rest"
history_contains '强提醒才置顶' '\\U5f3a\\U63d0\\U9192\\U624d\\U7f6e\\U9876' || fail "window layer policy did not gate topmost mode"

echo "==> Checking automation policy URL"
open "$URL_SCHEME://diagnostics/automation-policy"
wait_for_history '自动化策略状态已还原' '\\U81ea\\U52a8\\U5316\\U7b56\\U7565\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "automation policy did not restore test state"
history_contains '自动化策略压测' '\\U81ea\\U52a8\\U5316\\U7b56\\U7565\\U538b\\U6d4b' || fail "automation policy stress did not run"
history_contains '安静时段只发通知' '\\U5b89\\U9759\\U65f6\\U6bb5\\U53ea\\U53d1\\U901a\\U77e5' || fail "automation policy did not keep quiet hours notification-only"
history_contains '自动暂停命中' '\\U81ea\\U52a8\\U6682\\U505c\\U547d\\U4e2d' || fail "automation policy did not hit auto pause"
history_contains '自动暂停已关闭休息页' '\\U81ea\\U52a8\\U6682\\U505c\\U5df2\\U5173\\U95ed\\U4f11\\U606f\\U9875' || fail "automation policy did not close rest window"
history_contains '提醒时间已顺延' '\\U63d0\\U9192\\U65f6\\U95f4\\U5df2\\U987a\\U5ef6' || fail "automation policy did not shift reminder time"

echo "==> Checking presentation policy URL"
open "$URL_SCHEME://diagnostics/presentation-policy"
wait_for_history '演示策略状态已还原' '\\U6f14\\U793a\\U7b56\\U7565\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "presentation policy did not restore test state"
history_contains '演示策略压测' '\\U6f14\\U793a\\U7b56\\U7565\\U538b\\U6d4b' || fail "presentation policy stress did not run"
history_contains '演示模式只发通知' '\\U6f14\\U793a\\U6a21\\U5f0f\\U53ea\\U53d1\\U901a\\U77e5' || fail "presentation policy did not keep notification-only"
history_contains '演示命中已关闭休息页' '\\U6f14\\U793a\\U547d\\U4e2d\\U5df2\\U5173\\U95ed\\U4f11\\U606f\\U9875' || fail "presentation policy did not close rest window"
history_contains '恢复自检不弹休息页' '\\U6062\\U590d\\U81ea\\U68c0\\U4e0d\\U5f39\\U4f11\\U606f\\U9875' || fail "presentation policy recovery check popped rest window"

echo "==> Checking live presentation policy URL"
open "$URL_SCHEME://diagnostics/presentation-live"
sleep 4
history_contains '真实演示联动自检' '\\U771f\\U5b9e\\U6f14\\U793a\\U8054\\U52a8\\U81ea\\U68c0' || fail "live presentation policy check did not run"
if ! history_contains '跳过' '\\U8df3\\U8fc7' '真实演示命中' '\\U771f\\U5b9e\\U6f14\\U793a\\U547d\\U4e2d' '测试状态已还原' '\\U6d4b\\U8bd5\\U72b6\\U6001\\U5df2\\U8fd8\\U539f'; then
  fail "live presentation policy check did not record skip or pass state"
fi

echo "==> Checking calendar policy URL"
open "$URL_SCHEME://diagnostics/calendar-policy"
wait_for_history '日历策略状态已还原' '\\U65e5\\U5386\\U7b56\\U7565\\U72b6\\U6001\\U5df2\\U8fd8\\U539f' || fail "calendar policy did not restore test state"
history_contains '日历策略压测' '\\U65e5\\U5386\\U7b56\\U7565\\U538b\\U6d4b' || fail "calendar policy stress did not run"
history_contains '日历会议只发通知' '\\U65e5\\U5386\\U4f1a\\U8bae\\U53ea\\U53d1\\U901a\\U77e5' || fail "calendar policy did not keep meeting notification-only"
history_contains '日程暂停命中' '\\U65e5\\U7a0b\\U6682\\U505c\\U547d\\U4e2d' || fail "calendar policy did not hit calendar auto-pause"
history_contains '日程暂停已关闭休息页' '\\U65e5\\U7a0b\\U6682\\U505c\\U5df2\\U5173\\U95ed\\U4f11\\U606f\\U9875' || fail "calendar policy did not close rest window"
history_contains '提醒时间已顺延' '\\U63d0\\U9192\\U65f6\\U95f4\\U5df2\\U987a\\U5ef6' || fail "calendar policy did not shift reminder time"
history_contains '统计已还原' '\\U7edf\\U8ba1\\U5df2\\U8fd8\\U539f' || fail "calendar policy did not restore stats"

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
