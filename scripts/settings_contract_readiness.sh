#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OBJC_FILE="$ROOT_DIR/Sources/EyeRestObjC/main.m"
SWIFT_FILE="$ROOT_DIR/Sources/EyeRest/main.swift"
CONTRACT_FILE="$ROOT_DIR/docs/settings-contract.json"
STRICT=0

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "${LC_ALL:-}" == "C.UTF-8" ]] && export LC_ALL="en_US.UTF-8"
  [[ "${LC_CTYPE:-}" == "C.UTF-8" ]] && export LC_CTYPE="en_US.UTF-8"
  [[ "${LANG:-}" == "C.UTF-8" || -z "${LANG:-}" ]] && export LANG="en_US.UTF-8"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/settings_contract_readiness.sh
  scripts/settings_contract_readiness.sh --strict

Prints a read-only UserDefaults/settings-contract report for future SwiftUI migration.
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
  printf '  %-30s %s\n' "$key:" "$value"
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
  [[ -f "$file" ]] && grep -Fq "$token" "$file"
}

setting_keys() {
  sed -n 's/^static NSString \*const \(ERSettings[A-Za-z0-9]*Key\) = @".*";$/\1/p' "$OBJC_FILE"
}

setting_key_values() {
  sed -n 's/^static NSString \*const ERSettings[A-Za-z0-9]*Key = @"\([^"]*\)";$/\1/p' "$OBJC_FILE"
}

contract_key_values() {
  awk '
    /"keys"[[:space:]]*:/ { in_keys = 1; next }
    /"legacyKeys"[[:space:]]*:/ { in_keys = 0 }
    in_keys { print }
  ' "$CONTRACT_FILE" | sed -n 's/.*"key": "\([^"]*\)".*/\1/p'
}

print_section "Sources"
if [[ -f "$OBJC_FILE" ]]; then ok "Objective-C app"; else fail_check "Objective-C app" "missing"; fi
if [[ -f "$SWIFT_FILE" ]]; then ok "SwiftUI draft"; else fail_check "SwiftUI draft" "missing"; fi
if [[ -f "$CONTRACT_FILE" ]]; then ok "Settings contract doc"; else fail_check "Settings contract doc" "missing docs/settings-contract.json"; fi

print_section "Objective-C UserDefaults Contract"
KEY_NAMES="$(setting_keys | sort)"
KEY_VALUES="$(setting_key_values | sort)"
KEY_COUNT="$(printf '%s\n' "$KEY_VALUES" | sed '/^$/d' | wc -l | tr -d ' ')"
print_kv "Settings key count" "$KEY_COUNT"
if [[ "$KEY_COUNT" -gt 0 ]]; then
  ok "Settings key extraction"
else
  fail_check "Settings key extraction" "no ERSettings keys found"
fi
for key in eyeEnabled eyeMode eyeFocusSeconds eyeRestSeconds standEnabled standIntervalSeconds standDurationSeconds standRoutine standIntensity standCustomStages showRestWindow restWindowTopmost notificationsEnabled restStyle menuBarMode autoFocusModeEnabled calendarFocusModeEnabled presentationFocusModeEnabled quietHoursEnabled quietHoursStartMinute quietHoursEndMinute; do
  if printf '%s\n' "$KEY_VALUES" | grep -Fxq "$key"; then
    ok "$key"
  else
    fail_check "$key" "missing from Objective-C settings contract"
  fi
done

if contains "$OBJC_FILE" "registerDefaults:registered"; then ok "Default registration"; else fail_check "Default registration" "missing"; fi
if contains "$OBJC_FILE" "applyBackupSettingsDictionary"; then ok "Backup restore path"; else warn "Backup restore path" "missing"; fi
if contains "$OBJC_FILE" "workMinutes" && contains "$OBJC_FILE" "restSeconds"; then ok "Legacy migration"; else warn "Legacy migration" "old work/rest keys not visible"; fi

print_section "Machine-Readable Contract"
if contains "$CONTRACT_FILE" "\"schemaVersion\": 1" && contains "$CONTRACT_FILE" "\"storageModel\": \"per-key UserDefaults\""; then
  ok "Contract metadata"
else
  fail_check "Contract metadata" "missing schemaVersion or per-key storage model"
fi
if contains "$CONTRACT_FILE" "\"migrationRule\"" && contains "$CONTRACT_FILE" "\"swiftUIDraftStatus\": \"prototype only\""; then
  ok "Migration guard"
else
  fail_check "Migration guard" "missing migration rule or prototype-only status"
fi

CONTRACT_KEYS="$(contract_key_values | sort)"
CONTRACT_COUNT="$(printf '%s\n' "$CONTRACT_KEYS" | sed '/^$/d' | wc -l | tr -d ' ')"
print_kv "Contract key count" "$CONTRACT_COUNT"
if [[ "$CONTRACT_COUNT" == "$KEY_COUNT" ]]; then
  ok "Contract key count"
else
  fail_check "Contract key count" "contract=$CONTRACT_COUNT Objective-C=$KEY_COUNT"
fi

CONTRACT_MISSING=0
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if printf '%s\n' "$CONTRACT_KEYS" | grep -Fxq "$key"; then
    ok "contract key $key"
  else
    CONTRACT_MISSING=$((CONTRACT_MISSING + 1))
    fail_check "contract key $key" "missing from docs/settings-contract.json"
  fi
done <<< "$KEY_VALUES"

if contains "$CONTRACT_FILE" "\"legacyKeys\"" && contains "$CONTRACT_FILE" "\"workMinutes\"" && contains "$CONTRACT_FILE" "\"restSeconds\""; then
  ok "Legacy key mapping"
else
  fail_check "Legacy key mapping" "missing workMinutes/restSeconds migration notes"
fi
if contains "$CONTRACT_FILE" "\"minimumDebugValue\": 10" && contains "$CONTRACT_FILE" "\"quickSetupSeen\""; then
  ok "Debug and onboarding notes"
else
  warn "Debug and onboarding notes" "minimum 10s or quick setup note missing"
fi

print_section "SwiftUI Draft Storage"
if contains "$SWIFT_FILE" "private let key = \"EyeRestSettings\""; then
  warn "Swift storage key" "uses one JSON blob: EyeRestSettings"
else
  ok "Swift storage key"
fi
if contains "$SWIFT_FILE" "JSONEncoder().encode(settings)" && contains "$SWIFT_FILE" "JSONDecoder().decode(EyeRestSettings.self"; then
  warn "Swift storage format" "JSON blob does not share the Objective-C per-key schema"
else
  ok "Swift storage format"
fi

MAPPED=0
MISSING=0
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if contains "$SWIFT_FILE" "$key"; then
    MAPPED=$((MAPPED + 1))
  else
    MISSING=$((MISSING + 1))
  fi
done <<< "$KEY_VALUES"
print_kv "Swift mapped keys" "$MAPPED/$KEY_COUNT"
print_kv "Swift missing keys" "$MISSING"

if [[ "$MISSING" -gt 0 ]]; then
  warn "Contract parity" "$MISSING Objective-C settings keys are not represented by name in the SwiftUI draft"
else
  ok "Contract parity"
fi

print_section "Required Migration Contract"
for token in eyeFocusSeconds eyeRestSeconds standIntervalSeconds standDurationSeconds restWindowTopmost restStyle menuBarMode focusAppTokens calendarFocusTokens quietHoursStartMinute; do
  if contains "$SWIFT_FILE" "$token"; then
    ok "Swift token $token"
  else
    warn "Swift token $token" "missing before SwiftUI can replace the shipping app"
  fi
done

print_section "Recommendation"
if [[ "$MISSING" -gt 0 ]]; then
  print_kv "Contract status" "prototype only"
  echo "  Next:"
  echo "  - Keep Objective-C/AppKit as the shipping app."
  echo "  - Before switching, make SwiftUI read and write the same per-key UserDefaults schema or provide an explicit migration layer."
  echo "  - Preserve backup JSON, URL scheme behavior, seconds-level debug rhythm, and dual timer keys."
else
  print_kv "Contract status" "ready for migration tests"
fi

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "settings contract assessed"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
