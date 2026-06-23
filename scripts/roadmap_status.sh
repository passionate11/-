#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/Sources/EyeRestObjC/main.m"
README_FILE="$ROOT_DIR/README.md"
VERSION_FILE="$ROOT_DIR/VERSION"
SWIFTUI_PLAN_FILE="$ROOT_DIR/docs/swiftui-migration-plan.json"
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
  [[ -f "$file" ]] && grep -Fq -- "$token" "$file"
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
check_evidence "settings diagnostic button" "copyAutomationDiagnosticFromSettings:"
check_evidence "issue section" "section=automation-policy"
check_evidence "keyword catalog marker" "automation_keyword_catalog"
check_evidence "keyword catalog upgrade" "ERUpgradedAutomationTokensIfUncustomized"
check_evidence "meeting keywords" "com.cisco.webexmeetingsapp"
check_evidence "video game keywords" "battle.net"
check_evidence "recording keywords" "com.telestream.screenflow"
check_evidence "calendar exam keyword" "考试"
check_evidence "automation policy readiness" "automation policy assessed" "$ROOT_DIR/scripts/automation_policy_readiness.sh"
print_kv "Status" "implemented-with-diagnostics"

print_section "v0.1.48 Settings Visual Polish"
check_evidence "wide settings window" "NSMakeRect(0, 0, 944, 592)"
check_evidence "sidebar divider" "sidebarDividerView"
check_evidence "sidebar nav group" "sidebarNavGroupView"
check_evidence "sidebar no-draw button" "ERSettingsSidebarButton"
check_evidence "quiet selected row" "unemphasizedSelectedContentBackgroundColor"
check_evidence "soft content background" "ERColor(0.972, 0.974, 0.979, 1)"
check_evidence "compact sidebar controls" "NSMakeRect(6, 172 - index * 34, 196, 30)"
check_evidence "quiet page header" "NSMakeRect(54, 402, 28, 2)"
check_evidence "wide quiet card" "NSMakeRect(0, 0, 664, 332)"
check_evidence "initial card shadow" "card.layer.shadowOpacity = 0.004"
check_evidence "small time inputs" "field.controlSize = NSControlSizeSmall"
check_evidence "overview light actions" "overviewActionButtonShells"
check_evidence "overview insight band" "overviewInsightBand"
check_evidence "overview accent views" "overviewAccentViews"
check_evidence "settings accent contrast" "ERSettingsAccentColor"
check_evidence "toolbar action shells" "shell.layer.borderWidth = settingsDarkStyle ? 0.5 : 0"
check_evidence "page icon badges" "pageIconBadgeViews"
check_evidence "style preview motif" "stylePreviewMotif"
check_evidence "settings visual readiness" "settings visual assessed" "$ROOT_DIR/scripts/settings_visual_readiness.sh"
print_kv "Status" "implemented-visual-polish-pass"

print_section "v0.1.47 Distribution Maintenance"
check_evidence "release readiness" "发布就绪检查" "$README_FILE"
check_evidence "auto update readiness" "自动更新准备检查" "$README_FILE"
check_evidence "notarization readiness" "公证准备检查" "$README_FILE"
check_evidence "SwiftUI migration" "SwiftUI 迁移准备检查" "$README_FILE"
check_evidence "SwiftUI parity matrix" "swiftui-parity-matrix.json" "$README_FILE"
check_evidence "SwiftUI parity machine file" "\"migrationStatus\": \"prototype only\"" "$ROOT_DIR/docs/swiftui-parity-matrix.json"
check_evidence "SwiftUI phase plan docs" "SwiftUI 迁移阶段计划" "$README_FILE"
check_evidence "SwiftUI phase plan file" "\"settings-contract-foundation\"" "$SWIFTUI_PLAN_FILE"
check_evidence "SwiftUI phase plan script" "SwiftUI parity plan assessed" "$ROOT_DIR/scripts/swiftui_parity_plan.sh"
check_evidence "settings contract" "设置合约准备检查" "$README_FILE"
check_evidence "settings contract json" "settings-contract.json" "$README_FILE"
check_evidence "settings contract machine file" "\"storageModel\": \"per-key UserDefaults\"" "$ROOT_DIR/docs/settings-contract.json"
check_evidence "checksum artifact" "zip.sha256" "$README_FILE"
check_evidence "release notes" "发布说明生成" "$README_FILE"
check_evidence "release evidence bundle" "发布证据包" "$README_FILE"
check_evidence "release evidence readiness docs" "发布证据包就绪检查" "$README_FILE"
check_evidence "auto update script" "auto_update_readiness.sh" "$SOURCE_FILE"
check_evidence "release evidence script" "capture_release_evidence.sh" "$ROOT_DIR/scripts/capture_release_evidence.sh"
check_evidence "release evidence readiness script" "release evidence assessed" "$ROOT_DIR/scripts/release_evidence_readiness.sh"
check_evidence "release evidence parity plan" "swiftui_parity_plan" "$ROOT_DIR/scripts/capture_release_evidence.sh"
print_kv "Status" "implemented-release-readiness"

print_section "Product Surface"
check_evidence "roadmap copy action" "copyRoadmapStatus:"
check_evidence "roadmap text" "roadmapStatusText"
check_evidence "roadmap URL" "diagnostics/roadmap-status"
check_evidence "next action plan" "nextActionPlan=1"
check_evidence "next action priorities" "P1-product-polish,P2-automation-fit,P3-release-record"
check_evidence "low disruption checks" "不跑全屏冒烟"
check_evidence "support bundle section" "section=roadmap-status"
check_evidence "auto update copy action" "copyAutoUpdateReadiness:"
check_evidence "auto update text" "autoUpdateReadinessText"
check_evidence "settings contract script" "settings_contract_readiness.sh" "$ROOT_DIR/scripts/settings_contract_readiness.sh"
check_evidence "settings visual script" "settings_visual_readiness.sh" "$ROOT_DIR/scripts/settings_visual_readiness.sh"
check_evidence "SwiftUI parity plan script" "swiftui_parity_plan.sh" "$ROOT_DIR/scripts/swiftui_parity_plan.sh"
check_evidence "automation policy script" "automation_policy_readiness.sh" "$ROOT_DIR/scripts/automation_policy_readiness.sh"
check_evidence "release evidence script" "release_evidence_readiness.sh" "$ROOT_DIR/scripts/release_evidence_readiness.sh"

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
