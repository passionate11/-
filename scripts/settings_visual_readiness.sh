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
  scripts/settings_visual_readiness.sh
  scripts/settings_visual_readiness.sh --strict

Prints a read-only settings-window visual readiness report without launching the app.
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

check_not_token() {
  local label="$1"
  local token="$2"
  local file="${3:-$SOURCE_FILE}"
  if contains "$file" "$token"; then
    fail_check "$label" "unexpected token: $token"
  else
    ok "$label"
  fi
}

print_section "Sources"
[[ -f "$SOURCE_FILE" ]] && ok "Objective-C app" || fail_check "Objective-C app" "missing"
[[ -f "$README_FILE" ]] && ok "README" || fail_check "README" "missing"
[[ -f "$CHANGELOG_FILE" ]] && ok "CHANGELOG" || warn "CHANGELOG" "missing"

print_section "Window Shell"
check_token "944px settings window" "NSMakeRect(0, 0, 944, 592)"
check_token "transparent titlebar" "titlebarAppearsTransparent"
check_token "normal window level" "window.level = NSNormalWindowLevel;"
check_token "sidebar material" "NSVisualEffectMaterialSidebar"
check_token "soft content background" "ERColor(0.964, 0.967, 0.974, 1)"
check_token "content width" "NSMakeRect(256, 86, 648, 430)"
check_token "wide card" "NSMakeRect(0, 0, 648, 306)"
check_not_token "no utility settings panel" "NSWindowStyleMaskUtilityWindow"
check_not_token "no floating settings panel" "NSFloatingWindowLevel"

print_section "Sidebar"
check_token "brand badge" "sidebarBrandBadge"
check_token "compact brand badge" "NSMakeRect(24, 512, 44, 44)"
check_token "brand subtitle" "护眼 · 站立 · 专注"
check_token "summary card" "sidebarSummaryCard"
check_token "soft summary card" "NSMakeRect(22, 422, 188, 74)"
check_token "summary accent" "sidebarSummaryAccentView"
check_token "non-drawing sidebar button" "ERSettingsSidebarButton"
check_token "sidebar button draw guard" "- (void)drawRect:(NSRect)dirtyRect"
check_token "transparent hit area" "button.transparent = YES"
check_token "nearly invisible hit area" "button.alphaValue = 0.001"
check_token "no button highlight" "setHighlightsBy:NSNoCellMask"
check_token "selected indicator" "sidebarNavIndicatorViews"
check_token "compact nav row" "NSMakeRect(14, 341 - index * 36, 204, 31)"
check_token "icon badge layer" "sidebarNavIconBadgeViews"
check_token "compact nav icon" "configurationWithPointSize:13"
check_token "custom nav labels" "sidebarNavTitleLabels"
check_token "custom nav icons" "sidebarNavIconViews"
check_token "native quiet selected row" "[NSColor unemphasizedSelectedContentBackgroundColor]"
check_token "selected icon accent" "selectedIconColor"

print_section "Pages"
check_token "page icon badge" "pageIconBadgeViews"
check_token "compact page icon badge" "NSMakeRect(2, 382, 38, 38)"
check_token "page accent" "pageAccentViews"
check_token "quiet page accent" "NSMakeRect(54, 384, 28, 2)"
check_token "overview wide status band" "NSMakeRect(24, 236, 600, 52)"
check_token "overview dual timer width" "NSMakeRect(24, 132, 290, 90)"
check_token "overview action bar" "NSMakeRect(24, 22, 600, 34)"
check_token "eye summary wide" "NSMakeRect(24, 232, 600, 54)"
check_token "eye rows wide" "NSMakeRect(24, 176, 600, 42)"
check_token "stand rows wide" "NSMakeRect(24, 184, 600, 34)"
check_token "display rows wide" "NSMakeRect(24, 232, 374, 32)"
check_token "style preview panel" "NSMakeRect(424, 52, 184, 212)"
check_token "automation summary wide" "NSMakeRect(24, 190, 600, 80)"
check_token "stats header spacing" "NSMakeRect(32, 238, 348, 22)"

print_section "Theme Noise Control"
check_token "transparent grouped rows" "[NSColor colorWithWhite:1 alpha:0.0]"
check_token "low action bar opacity" "[theme.cardBorder colorWithAlphaComponent:0.045]"
check_token "toolbar action shells" "shell.layer.borderWidth = settingsDarkStyle ? 0.5 : 0"
check_token "initial card shadow reduced" "card.layer.shadowOpacity = 0.014"
check_token "reduced card shadow" "card.layer.shadowRadius = settingsDarkStyle ? 14 : 10"
check_token "reduced card motif" "settings-card-motif\", 0.030"
check_token "dark contrast guard" "settingsDarkStyle = self.settings.restStyle == ERRestStyleNight"
check_token "theme-aware preview" "stylePreviewMotif"
check_token "theme-aware page icons" "icon.contentTintColor = theme.accent"

print_section "Docs"
check_token "visual readiness docs" "设置页视觉就绪检查" "$README_FILE"
check_token "current polish docs" "设置页视觉再设计" "$README_FILE"
check_token "changelog entry" "设置页视觉再设计" "$CHANGELOG_FILE"

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "settings visual assessed"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
