#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/Sources/EyeRestObjC/main.m"
README_FILE="$ROOT_DIR/README.md"
VERSION_FILE="$ROOT_DIR/VERSION"
STRICT=0

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/roadmap_status.sh
  scripts/roadmap_status.sh --strict

Prints a read-only roadmap evidence snapshot for the current 松一下 todo plan.
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

check_evidence() {
  local label="$1"
  local token="$2"
  local file="${3:-$SOURCE_FILE}"
  if contains "$file" "$token"; then
    ok "$label"
  else
    fail_check "$label" "missing token: $token"
  fi
}

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || true)"

print_section "Roadmap Snapshot"
print_kv "Checked at" "$(date '+%Y-%m-%d %H:%M:%S %z')"
print_kv "Version" "${VERSION:-missing}"
print_kv "Repository" "$ROOT_DIR"

print_section "v0.1.45 Automation Experience"
check_evidence "policy explanation" "automationPolicyExplanation"
check_evidence "last action label" "automationLastActionLabel"
check_evidence "diagnostic text" "automationDiagnosticText"
check_evidence "issue section" "section=automation-policy"
print_kv "Status" "implemented-with-diagnostics"

print_section "v0.1.46 Settings Polish"
check_evidence "wide settings window" "NSMakeRect(0, 0, 920, 592)"
check_evidence "sidebar divider" "sidebarDividerView"
check_evidence "overview light actions" "overviewActionButtonShells"
check_evidence "page icon badges" "pageIconBadgeViews"
check_evidence "style preview motif" "stylePreviewMotif"
print_kv "Status" "implemented-polish-pass"

print_section "v0.1.47 Distribution Maintenance"
check_evidence "release readiness" "发布就绪检查" "$README_FILE"
check_evidence "notarization readiness" "公证准备检查" "$README_FILE"
check_evidence "SwiftUI migration" "SwiftUI 迁移准备检查" "$README_FILE"
check_evidence "checksum artifact" "zip.sha256" "$README_FILE"
check_evidence "release notes" "发布说明生成" "$README_FILE"
print_kv "Status" "implemented-release-readiness"

print_section "Product Surface"
check_evidence "roadmap copy action" "copyRoadmapStatus:"
check_evidence "roadmap text" "roadmapStatusText"
check_evidence "roadmap URL" "diagnostics/roadmap-status"
check_evidence "support bundle section" "section=roadmap-status"

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "roadmap evidence captured"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
