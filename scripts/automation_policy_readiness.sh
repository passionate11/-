#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/Sources/EyeRestObjC/main.m"
README_FILE="$ROOT_DIR/README.md"
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"
STRICT=0

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "${LC_ALL:-}" == "C.UTF-8" ]] && export LC_ALL="en_US.UTF-8"
  [[ "${LC_CTYPE:-}" == "C.UTF-8" ]] && export LC_CTYPE="en_US.UTF-8"
  [[ "${LANG:-}" == "C.UTF-8" || -z "${LANG:-}" ]] && export LANG="en_US.UTF-8"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/automation_policy_readiness.sh
  scripts/automation_policy_readiness.sh --strict

Prints a read-only automation-policy readiness report without launching the app.
HELP
  exit 0
fi

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

FAILURES=0
WARNINGS=0

print_section() {
  printf '\n== %s ==\n' "$1"
}

print_kv() {
  local key="$1"
  local value="${2:-}"
  [[ -z "$value" ]] && value="-"
  printf '  %-32s %s\n' "$key:" "$value"
}

ok() {
  print_kv "$1" "ok"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  print_kv "$1" "warn - $2"
}

fail_check() {
  FAILURES=$((FAILURES + 1))
  print_kv "$1" "fail - $2"
}

contains() {
  local file="$1"
  local token="$2"
  [[ -f "$file" ]] && grep -Fq -- "$token" "$file"
}

check_token() {
  local label="$1"
  local token="$2"
  local file="${3:-$SOURCE_FILE}"
  if contains "$file" "$token"; then
    ok "$label"
  else
    fail_check "$label" "missing token: $token"
  fi
}

print_section "Sources"
[[ -f "$SOURCE_FILE" ]] && ok "Objective-C app" || fail_check "Objective-C app" "missing"
[[ -f "$README_FILE" ]] && ok "README" || fail_check "README" "missing"
[[ -f "$CHANGELOG_FILE" ]] && ok "CHANGELOG" || warn "CHANGELOG" "missing"

print_section "Policy Explanation"
check_token "policy helper" "automationPolicyExplanation"
check_token "final action text" "最终动作："
check_token "reason text" "命中原因："
check_token "last action text" "最近动作："
check_token "next step text" "建议下一步："
check_token "disabled policy branch" "自动策略已关闭"
check_token "ignore branch" "忽略策略命中"
check_token "app auto-pause branch" "自动暂停应用命中"
check_token "calendar auto-pause branch" "日程暂停关键词命中"
check_token "manual focus branch" "手动轻打扰已开启"
check_token "presentation branch" "检测到全屏/演示状态"
check_token "quiet hours branch" "安静时段命中"
check_token "calendar focus branch" "日历会议命中"
check_token "app focus branch" "轻打扰应用命中"

print_section "Settings Surface"
check_token "automation page title" "pageViewWithTitle:@\"自动化\""
check_token "current policy section" "策略结论"
check_token "scenario section" "场景模式"
check_token "quiet hours section" "固定时段"
check_token "advanced section" "高级策略"
check_token "policy status label" "focusAppMatchLabel"
check_token "suggestion label" "automationPolicyLabel"
check_token "last action label" "automationLastActionLabel"
check_token "policy stripe" "automationStatusStripe"
check_token "settings diagnostic button" "automationDiagnosticButton"
check_token "settings diagnostic action" "copyAutomationDiagnosticFromSettings:"
check_token "calendar status label" "calendarStatusLabel"
check_token "quiet status label" "quietHoursStatusLabel"

print_section "Keyword Editor"
check_token "keyword sheet" "策略关键词"
check_token "plain priority copy" "优先级：不处理 > 自动暂停 > 只发通知。"
check_token "keyword priority hint" "命中多个策略时，会按"
check_token "restore defaults button" "恢复默认"
check_token "app policy section" "应用策略"
check_token "calendar policy section" "日程策略"
check_token "app match explanation" "按前台应用名称或 bundle id 命中。"
check_token "calendar match explanation" "按日程标题、地点或日历名称命中。"
check_token "current app label" "当前应用："
check_token "current event label" "当前日程："
check_token "append notify button" "加到只通知"
check_token "append auto pause button" "加到自动暂停"
check_token "append ignore button" "加到不处理"
check_token "append calendar notify button" "加到日程只通知"
check_token "append calendar pause button" "加到日程自动暂停"
check_token "recommended templates label" "推荐模板"
check_token "meeting template" "会议协作"
check_token "video template" "视频游戏"
check_token "recording template" "录制面试"
check_token "template append action" "appendAutomationKeywordTemplate:"
check_token "template append helper" "ERJoinedFocusTokensByAppendingTokens"
check_token "append selector" "appendCurrentAppToAutomationKeywordField:"
check_token "append helper" "ERJoinedFocusTokensByAppendingToken"
check_token "external app cache" "lastExternalAppBundleIdentifier"
check_token "notify label" "只通知"
check_token "auto pause label" "自动暂停"
check_token "ignore label" "不处理"
check_token "app notify placeholder" "应用只通知："
check_token "app pause placeholder" "应用自动暂停："
check_token "app ignore placeholder" "应用不处理："
check_token "calendar notify placeholder" "日程只通知："
check_token "calendar pause placeholder" "日程自动暂停："
check_token "default restore path" "ERDefaultFocusAppTokens"
check_token "keyword sanitizer" "ERSanitizedFocusAppTokensFromObject"

print_section "Keyword Catalog"
check_token "legacy default catalog" "ERLegacyDefaultFocusAppTokens"
check_token "uncustomized upgrade" "ERUpgradedAutomationTokensIfUncustomized"
check_token "meeting webex app" "com.cisco.webexmeetingsapp"
check_token "meeting skype app" "com.skype.skype"
check_token "meeting weekly tokens" "周会"
check_token "meeting retrospective token" "retrospective"
check_token "video movist app" "com.movist.mac"
check_token "video plex app" "com.plexapp.plex"
check_token "game battle net token" "battle.net"
check_token "game riot token" "riot client"
check_token "recording screenflow app" "com.telestream.screenflow"
check_token "recording camtasia app" "com.techsmith.camtasia"
check_token "recording screen capture token" "录屏"
check_token "recording defense token" "答辩"
check_token "exam token" "考试"
check_token "catalog roadmap marker" "automation_keyword_catalog"

print_section "Diagnostics And Feedback"
check_token "automation diagnostic" "automationDiagnosticText"
check_token "diagnostic strategy section" "策略结论："
check_token "issue bundle section" "section=automation-policy"
check_token "support bundle automation" "--- 自动化诊断 ---"
check_token "diagnostic URL" "diagnostics/automation-policy"
check_token "copy diagnostic action" "copyAutomationDiagnostic:"
check_token "settings diagnostic action" "copyAutomationDiagnosticFromSettings:"
check_token "policy stress action" "runAutomationPolicyStressTest:"
check_token "roadmap evidence" "automation_policy_readiness.sh"

print_section "Docs"
check_token "readiness docs" "自动化策略就绪检查" "$README_FILE"
check_token "script docs" "scripts/automation_policy_readiness.sh" "$README_FILE"
check_token "catalog docs" "自动化关键词目录" "$README_FILE"
check_token "roadmap docs" "v0.1.45 自动化真实体验补强" "$README_FILE"
check_token "changelog entry" "自动化关键词目录" "$CHANGELOG_FILE"

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "automation policy assessed"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
