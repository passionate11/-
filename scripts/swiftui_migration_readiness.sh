#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_FILE="$ROOT_DIR/Sources/EyeRest/main.swift"
OBJC_FILE="$ROOT_DIR/Sources/EyeRestObjC/main.m"
PACKAGE_FILE="$ROOT_DIR/Package.swift"
STRICT=0

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/swiftui_migration_readiness.sh
  scripts/swiftui_migration_readiness.sh --strict

Prints a read-only readiness report for migrating 松一下 from the current Objective-C/AppKit app to SwiftUI.
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
  printf '  %-28s %s\n' "$key:" "$value"
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
  [[ -f "$file" ]] && grep -q "$token" "$file"
}

line_count() {
  [[ -f "$1" ]] && wc -l < "$1" | tr -d ' ' || echo 0
}

print_section "Sources"
if [[ -f "$PACKAGE_FILE" ]]; then ok "Package.swift"; else fail_check "Package.swift" "missing"; fi
if [[ -f "$SWIFT_FILE" ]]; then ok "SwiftUI draft"; else fail_check "SwiftUI draft" "missing"; fi
if [[ -f "$OBJC_FILE" ]]; then ok "Objective-C app"; else fail_check "Objective-C app" "missing"; fi
print_kv "Swift lines" "$(line_count "$SWIFT_FILE")"
print_kv "Objective-C lines" "$(line_count "$OBJC_FILE")"

if contains "$PACKAGE_FILE" "SwiftUI" && contains "$PACKAGE_FILE" "AppKit"; then
  ok "Swift package frameworks"
else
  fail_check "Swift package frameworks" "Package.swift must link SwiftUI and AppKit"
fi

if contains "$SWIFT_FILE" "@main" && contains "$SWIFT_FILE" "NSStatusItem" && contains "$SWIFT_FILE" "NSHostingView"; then
  ok "Swift app skeleton"
else
  fail_check "Swift app skeleton" "draft must contain @main, menu bar item, and SwiftUI hosting view"
fi

print_section "Feature Parity"
FEATURES=(
  "eye/stand independent timers|standDueAt|Stand"
  "seconds-level debug rhythm|eyeRestSeconds|secondsField"
  "settings window|ERSettingsWindowController|SettingsView"
  "overview dashboard|overviewStatusBand|overview"
  "rest overlay yield/topmost policy|restOverlayYielded|restOverlayYielded"
  "display recovery|displayDiagnosticText|NSScreen"
  "automation policy|automationPolicyExplanation|focus"
  "calendar/presentation light distraction|calendarFocusActive|EventKit"
  "stats backup/export|exportStatsJSON|Export"
  "release/update/support flow|checkForUpdates|GitHub"
)

MISSING=0
for item in "${FEATURES[@]}"; do
  IFS='|' read -r label objc_token swift_token <<< "$item"
  if contains "$OBJC_FILE" "$objc_token" && contains "$SWIFT_FILE" "$swift_token"; then
    ok "$label"
  elif contains "$OBJC_FILE" "$objc_token"; then
    MISSING=$((MISSING + 1))
    warn "$label" "not represented in SwiftUI draft"
  else
    warn "$label" "Objective-C anchor not found; review readiness script"
  fi
done

print_section "Tooling"
if command -v swift >/dev/null 2>&1; then
  SWIFT_VERSION="$(swift --version 2>/dev/null | head -n 1)"
  print_kv "swift" "$SWIFT_VERSION"
else
  warn "swift" "not found"
fi

if [[ -d "$ROOT_DIR/.github/workflows" ]]; then
  ok "CI workflow directory"
else
  warn "CI workflow directory" "missing"
fi

print_section "Recommendation"
if [[ "$MISSING" -gt 0 ]]; then
  print_kv "Migration status" "prototype only"
  print_kv "Missing parity areas" "$MISSING"
  echo "  Next:"
  echo "  - Keep Objective-C/AppKit as the shipping app."
  echo "  - Port settings, dual timers, automation, recovery, stats, and release support before considering a switch."
  echo "  - Add SwiftUI parity tests only after the draft owns the same UserDefaults schema and URL scheme behavior."
else
  print_kv "Migration status" "ready for deeper build validation"
fi

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "migration assessed"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
