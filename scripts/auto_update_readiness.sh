#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_TARGET="${APP_TARGET:-$ROOT_DIR/outputs/EyeRest.app}"
ARCHIVE_PATH="${ARCHIVE_PATH:-}"
SOURCE_FILE="$ROOT_DIR/Sources/EyeRestObjC/main.m"
README_FILE="$ROOT_DIR/README.md"
RELEASE_WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"
VERSION_FILE="$ROOT_DIR/VERSION"
STRICT=0

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "${LC_ALL:-}" == "C.UTF-8" ]] && export LC_ALL="en_US.UTF-8"
  [[ "${LC_CTYPE:-}" == "C.UTF-8" ]] && export LC_CTYPE="en_US.UTF-8"
  [[ "${LANG:-}" == "C.UTF-8" || -z "${LANG:-}" ]] && export LANG="en_US.UTF-8"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/auto_update_readiness.sh
  scripts/auto_update_readiness.sh --strict
  APP_TARGET=outputs/EyeRest.app ARCHIVE_PATH=dist/songyixia-0.1.44-1.zip scripts/auto_update_readiness.sh --strict

Prints a read-only auto-update readiness snapshot. It does not enable Sparkle or modify the app.
HELP
  exit 0
fi

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || true)"
if [[ -z "$ARCHIVE_PATH" && -n "$VERSION" ]]; then
  ARCHIVE_PATH="$(ls -t "$ROOT_DIR"/dist/songyixia-"$VERSION"-*.zip 2>/dev/null | head -n 1 || true)"
fi
CHECKSUM_PATH="${CHECKSUM_PATH:-$ARCHIVE_PATH.sha256}"

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
  [[ -f "$file" ]] && grep -Fq "$token" "$file"
}

plist_value() {
  local app_path="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$app_path/Contents/Info.plist" 2>/dev/null || true
}

print_section "Auto Update Snapshot"
print_kv "Checked at" "$(date '+%Y-%m-%d %H:%M:%S %z')"
print_kv "Version" "${VERSION:-missing}"
print_kv "App target" "$APP_TARGET"
print_kv "Archive" "${ARCHIVE_PATH:-missing}"

print_section "Current Manual Flow"
if contains "$SOURCE_FILE" "ERLatestReleaseAPIURLString" && contains "$SOURCE_FILE" "browser_download_url" && contains "$SOURCE_FILE" "下载 zip"; then
  ok "Manual update"
else
  fail_check "Manual update" "GitHub Release API direct zip flow is incomplete"
fi

if [[ -f "$RELEASE_WORKFLOW" ]] && contains "$RELEASE_WORKFLOW" "songyixia-*.zip" && contains "$RELEASE_WORKFLOW" "songyixia-*.zip.sha256"; then
  ok "GitHub release assets"
else
  fail_check "GitHub release assets" "release workflow must upload zip and sha256"
fi

if [[ -n "$ARCHIVE_PATH" && -s "$ARCHIVE_PATH" ]]; then
  ok "Release zip"
  if [[ -s "$CHECKSUM_PATH" ]]; then
    if (cd "$(dirname "$ARCHIVE_PATH")" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")" >/dev/null 2>&1); then
      ok "Release checksum"
    else
      fail_check "Release checksum" "sha256 file does not match archive"
    fi
  else
    warn "Release checksum" "missing until package/preflight runs"
  fi
else
  warn "Release zip" "missing until package/preflight runs"
fi

print_section "Sparkle Readiness"
SPARKLE_FRAMEWORK="$APP_TARGET/Contents/Frameworks/Sparkle.framework"
SPARKLE_PRESENT=0
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_PRESENT=1
  ok "Sparkle framework"
else
  warn "Sparkle framework" "not bundled; manual GitHub Release update remains current plan"
fi

SU_FEED_URL=""
SU_PUBLIC_KEY=""
if [[ -d "$APP_TARGET" ]]; then
  SU_FEED_URL="$(plist_value "$APP_TARGET" SUFeedURL)"
  SU_PUBLIC_KEY="$(plist_value "$APP_TARGET" SUPublicEDKey)"
  if [[ -n "$SU_FEED_URL" ]]; then ok "SUFeedURL"; else warn "SUFeedURL" "missing"; fi
  if [[ -n "$SU_PUBLIC_KEY" ]]; then ok "SUPublicEDKey"; else warn "SUPublicEDKey" "missing"; fi
else
  warn "App bundle" "not built yet"
fi

if [[ "$SPARKLE_PRESENT" == "1" ]]; then
  [[ -n "$SU_FEED_URL" ]] || fail_check "Sparkle feed" "Sparkle is bundled but SUFeedURL is missing"
  [[ -n "$SU_PUBLIC_KEY" ]] || fail_check "Sparkle public key" "Sparkle is bundled but SUPublicEDKey is missing"
fi

if [[ -f "$ROOT_DIR/sparkle/appcast.xml" || -f "$ROOT_DIR/appcast.xml" ]]; then
  ok "Appcast"
else
  warn "Appcast" "not present; required before Sparkle auto update"
fi

print_section "Signing And Gatekeeper"
if [[ -d "$APP_TARGET" && "$(command -v codesign 2>/dev/null)" ]]; then
  CODESIGN_DETAILS="$(codesign -dv "$APP_TARGET" 2>&1 || true)"
  SIGNATURE="$(printf '%s\n' "$CODESIGN_DETAILS" | awk -F= '/Signature=/{print $2; exit}')"
  TEAM_ID="$(printf '%s\n' "$CODESIGN_DETAILS" | awk -F= '/TeamIdentifier=/{print $2; exit}')"
  print_kv "Signature" "${SIGNATURE:-unknown}"
  print_kv "TeamIdentifier" "${TEAM_ID:-not set}"
  if [[ "$SIGNATURE" == "adhoc" || -z "$TEAM_ID" || "$TEAM_ID" == "not set" ]]; then
    warn "Developer ID" "not configured; do not enable background replacement yet"
  else
    ok "Developer ID"
  fi
else
  warn "codesign" "codesign missing or app not built"
fi

if contains "$README_FILE" "公证准备检查" && [[ -f "$ROOT_DIR/scripts/notarize_release.sh" ]]; then
  ok "Notarization plan"
else
  warn "Notarization plan" "missing docs or script"
fi

print_section "Recommendation"
if [[ "$SPARKLE_PRESENT" == "1" && -n "$SU_FEED_URL" && -n "$SU_PUBLIC_KEY" && "$FAILURES" == "0" ]]; then
  print_kv "Auto update status" "ready for appcast validation"
  echo "  Next:"
  echo "  - Validate appcast signatures, Developer ID signing, notarization, and rollback policy before public rollout."
else
  print_kv "Auto update status" "manual GitHub Release"
  echo "  Next:"
  echo "  - Keep 检查更新... opening the GitHub Release zip."
  echo "  - Add Developer ID signing and notarization before enabling automatic replacement."
  echo "  - Add Sparkle framework, SUFeedURL, SUPublicEDKey, appcast, and rollback notes only after public distribution is ready."
fi

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "auto update assessed"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
