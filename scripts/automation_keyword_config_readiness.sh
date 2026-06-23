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
  scripts/automation_keyword_config_readiness.sh
  scripts/automation_keyword_config_readiness.sh --strict

Prints a read-only automation keyword configuration readiness report. It does not
launch the app, open settings, or trigger a full-screen rest window.
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
  printf '  %-34s %s\n' "$key:" "$value"
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

run_behavior_checks() {
  ruby <<'RUBY'
def sanitize_tokens(object)
  raw = []
  if object.is_a?(Array)
    object.each { |item| raw.concat(item.to_s.split(/[\n,，;；]/)) }
  else
    raw.concat(object.to_s.split(/[\n,，;；]/))
  end
  seen = {}
  raw.each_with_object([]) do |item, tokens|
    token = item.strip
    next if token.empty?
    key = token.downcase
    next if seen[key]
    seen[key] = true
    tokens << token
  end
end

def append_token(existing_text, token)
  token = token.to_s.strip
  return existing_text.to_s if token.empty?
  tokens = sanitize_tokens(existing_text.to_s)
  seen = {}
  tokens.each { |item| seen[item.downcase] = true }
  tokens << token unless seen[token.downcase]
  tokens.join(", ")
end

def append_tokens(existing_text, tokens)
  tokens.reduce(existing_text.to_s) { |joined, token| append_token(joined, token) }
end

checks = {
  "dedupe existing token" => append_token("zoom, Teams", "zoom") == "zoom, Teams",
  "trim appended token" => append_token("zoom", "  Webex  ") == "zoom, Webex",
  "ignore empty token" => append_token("zoom", "  ") == "zoom",
  "split Chinese separators" => sanitize_tokens("zoom，Teams；飞书\n钉钉") == ["zoom", "Teams", "飞书", "钉钉"],
  "preserve existing custom token" => append_tokens("my-special-app", ["zoom", "my-special-app", "teams"]) == "my-special-app, zoom, teams",
  "template append is additive" => append_tokens("custom", ["zoom", "teams", "zoom"]) == "custom, zoom, teams"
}

failed = checks.select { |_name, pass| !pass }
if failed.empty?
  puts "behavior=ok"
  exit 0
else
  failed.each { |name, _pass| warn name }
  exit 1
end
RUBY
}

print_section "Sources"
[[ -f "$SOURCE_FILE" ]] && ok "Objective-C app" || fail_check "Objective-C app" "missing"
[[ -f "$README_FILE" ]] && ok "README" || fail_check "README" "missing"
[[ -f "$CHANGELOG_FILE" ]] && ok "CHANGELOG" || warn "CHANGELOG" "missing"

print_section "Append Semantics"
check_token "sanitizer" "ERSanitizedFocusAppTokensFromObject"
check_token "comma separators" "characterSetWithCharactersInString:@\"\\n,，;；\""
check_token "case-insensitive dedupe" "token.lowercaseString"
check_token "single append helper" "ERJoinedFocusTokensByAppendingToken"
check_token "empty token guard" "if (token.length == 0) return existingText ?: @\"\";"
check_token "append only when unseen" "if (![seen containsObject:normalized])"
check_token "multi append helper" "ERJoinedFocusTokensByAppendingTokens"
check_token "multi append loop" "joined = ERJoinedFocusTokensByAppendingToken(joined, token);"
if run_behavior_checks >/dev/null; then
  ok "append behavior simulation"
else
  fail_check "append behavior simulation" "dedupe/additive behavior mismatch"
fi

print_section "Keyword Sheet Actions"
check_token "keyword sheet" "策略关键词"
check_token "no overwrite copy" "追加常见场景关键词，不会覆盖已有内容。"
check_token "priority copy" "优先级：不处理 > 自动暂停 > 只发通知。"
check_token "current app token" "currentAppToken"
check_token "current app fallback" "externalBundle.length > 0 ? externalBundle : externalName"
check_token "current event token" "currentEventToken"
check_token "current event trim" "ERTrimmedString(self.appDelegate.currentCalendarEventTitle ?: @\"\")"
check_token "button field association" "ERAutomationAppendFieldAssociationKey"
check_token "button token association" "ERAutomationAppendTokenAssociationKey"
check_token "current app append action" "appendCurrentAppToAutomationKeywordField:"
check_token "current app disabled state" "button.enabled = currentAppToken.length > 0;"
check_token "current event disabled state" "button.enabled = currentEventToken.length > 0;"
check_token "append sets selected feedback" "sender.state = NSControlStateValueOn;"

print_section "Template Coverage"
check_token "template fields association" "ERAutomationTemplateFieldsAssociationKey"
check_token "template tokens association" "ERAutomationTemplateTokensAssociationKey"
check_token "template append action" "appendAutomationKeywordTemplate:"
check_token "template append helper" "ERJoinedFocusTokensByAppendingTokens(field.stringValue, tokens)"
check_token "meeting template" "\"title\": @\"会议协作\""
check_token "meeting focus apps" "@\"us.zoom.xos\", @\"zoom\", @\"com.tencent.meeting\""
check_token "meeting calendar tokens" "@\"会议\", @\"meeting\", @\"同步\", @\"sync\", @\"站会\""
check_token "video template" "\"title\": @\"视频游戏\""
check_token "video auto-pause apps" "@\"com.apple.quicktimeplayerx\", @\"quicktime\", @\"com.colliderli.iina\""
check_token "video game tokens" "@\"steam\", @\"epic games\", @\"battle.net\", @\"riot client\""
check_token "video calendar tokens" "@\"直播\", @\"观影\", @\"电影\", @\"webinar\", @\"live\", @\"streaming\""
check_token "recording template" "\"title\": @\"录制面试\""
check_token "recording apps" "@\"com.obsproject.obs-studio\", @\"obs\", @\"com.telestream.screenflow\""
check_token "recording calendar tokens" "@\"录制\", @\"录屏\", @\"recording\", @\"演讲\", @\"演示\""
check_token "defense and exam tokens" "@\"答辩\", @\"defense\", @\"考试\", @\"exam\""

print_section "Persistence Boundaries"
check_token "save sanitizes focus" "ERSanitizedFocusAppTokensFromObject(fields[0].stringValue)"
check_token "save sanitizes auto pause" "ERSanitizedFocusAppTokensFromObject(fields[1].stringValue)"
check_token "save sanitizes ignore" "ERSanitizedFocusAppTokensFromObject(fields[2].stringValue)"
check_token "save sanitizes calendar focus" "ERSanitizedFocusAppTokensFromObject(fields[3].stringValue)"
check_token "save sanitizes calendar pause" "ERSanitizedFocusAppTokensFromObject(fields[4].stringValue)"
check_token "restore focus defaults" "self.settings.focusAppTokens = ERDefaultFocusAppTokens();"
check_token "restore auto pause defaults" "self.settings.autoPauseAppTokens = ERDefaultAutoPauseAppTokens();"
check_token "restore ignore defaults" "self.settings.ignoreAppTokens = ERDefaultIgnoreAppTokens();"
check_token "restore calendar defaults" "self.settings.calendarFocusTokens = ERDefaultCalendarFocusTokens();"
check_token "restore calendar pause defaults" "self.settings.calendarAutoPauseTokens = ERDefaultCalendarAutoPauseTokens();"

print_section "Docs"
check_token "readiness docs" "自动化关键词配置检查" "$README_FILE"
check_token "script docs" "automation_keyword_config_readiness.sh" "$README_FILE"
check_token "low disruption docs" "不会启动 App，也不会触发全屏休息页" "$README_FILE"
check_token "changelog entry" "自动化关键词配置检查" "$CHANGELOG_FILE"

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "automation keyword config assessed"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
