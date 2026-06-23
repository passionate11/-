#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAPTURE_SCRIPT="$ROOT_DIR/scripts/capture_release_evidence.sh"
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
  scripts/release_evidence_readiness.sh
  scripts/release_evidence_readiness.sh --strict

Prints a read-only release-evidence readiness report. It does not build, launch the
app, or run the full-screen smoke test.
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
  local file="${3:-$CAPTURE_SCRIPT}"
  if contains "$file" "$token"; then
    ok "$label"
  else
    fail_check "$label" "missing token: $token"
  fi
}

print_section "Sources"
[[ -f "$CAPTURE_SCRIPT" ]] && ok "Capture script" || fail_check "Capture script" "missing"
[[ -f "$README_FILE" ]] && ok "README" || fail_check "README" "missing"
[[ -f "$CHANGELOG_FILE" ]] && ok "CHANGELOG" || warn "CHANGELOG" "missing"

print_section "Evidence Manifest"
check_token "machine marker" "releaseEvidence=1"
check_token "timestamp" "generatedAt="
check_token "version" "version="
check_token "build" "build="
check_token "repository" "repository="
check_token "archive path" "archive="
check_token "checksum path" "checksum="
check_token "failure count" "failures="
check_token "status section" "status:"
check_token "low disruption guard" "doesNotRun=full-screen smoke test"
check_token "machine-readable manifest" "manifest.json"
check_token "manifest command array" "\"commands\""
check_token "manifest sha" "archiveSha256"
check_token "human checklist" "evidence-checklist.md"
check_token "checklist command section" "Command Captures"

print_section "Captured Commands"
check_token "git status" "run_capture \"git_status\""
check_token "git log" "run_capture \"git_log\""
check_token "preflight" "run_capture \"preflight_release\""
check_token "release readiness" "run_capture \"release_readiness\""
check_token "auto update readiness" "run_capture \"auto_update_readiness\""
check_token "roadmap" "run_capture \"roadmap_status\""
check_token "settings visual" "run_capture \"settings_visual_readiness\""
check_token "automation keyword config" "run_capture \"automation_keyword_config_readiness\""
check_token "automation policy" "run_capture \"automation_policy_readiness\""
check_token "release evidence readiness" "run_capture \"release_evidence_readiness\""
check_token "settings contract" "run_capture \"settings_contract_readiness\""
check_token "SwiftUI migration" "run_capture \"swiftui_migration_readiness\""
check_token "SwiftUI phase plan" "run_capture \"swiftui_parity_plan\""
check_token "installed diagnosis" "run_capture \"diagnose_installed_app\""

print_section "Artifacts"
check_token "evidence directory" "release-evidence-"
check_token "release notes copy" "release-notes-"
check_token "archive checksum" "archive.sha256"
check_token "zip checksum copy" "CHECKSUM_PATH"
check_token "json manifest artifact" "write_manifest_json"
check_token "checklist artifact" "write_evidence_checklist"
check_token "temp cleanup" "trap cleanup EXIT"
check_token "command status" "exitStatus="
check_token "command timestamps" "startedAt="
check_token "command finish time" "finishedAt="

print_section "Docs"
check_token "release evidence docs" "发布证据包" "$README_FILE"
check_token "readiness docs" "发布证据包就绪检查" "$README_FILE"
check_token "manifest docs" "manifest.json" "$README_FILE"
check_token "checklist docs" "evidence-checklist.md" "$README_FILE"
check_token "low disruption docs" "不会运行全屏冒烟测试" "$README_FILE"
check_token "changelog entry" "发布证据包 manifest" "$CHANGELOG_FILE"

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "release evidence assessed"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
