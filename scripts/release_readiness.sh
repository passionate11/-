#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_TARGET="${APP_TARGET:-/Applications/松一下.app}"
ARCHIVE_PATH="${ARCHIVE_PATH:-}"
STRICT=0

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "${LC_ALL:-}" == "C.UTF-8" ]] && export LC_ALL="en_US.UTF-8"
  [[ "${LC_CTYPE:-}" == "C.UTF-8" ]] && export LC_CTYPE="en_US.UTF-8"
  [[ "${LANG:-}" == "C.UTF-8" || -z "${LANG:-}" ]] && export LANG="en_US.UTF-8"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/release_readiness.sh
  scripts/release_readiness.sh --strict
  APP_TARGET=outputs/EyeRest.app ARCHIVE_PATH=dist/songyixia-0.1.44-1.zip scripts/release_readiness.sh --strict

Prints a read-only release readiness snapshot for 松一下.
HELP
  exit 0
fi

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

EXPECTED_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION" 2>/dev/null || true)"
if [[ -z "$ARCHIVE_PATH" && -n "$EXPECTED_VERSION" ]]; then
  ARCHIVE_PATH="$(ls -t "$ROOT_DIR"/dist/songyixia-"$EXPECTED_VERSION"-*.zip 2>/dev/null | head -n 1 || true)"
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
  if [[ -z "$value" ]]; then
    value="-"
  fi
  printf '  %-24s %s\n' "$key:" "$value"
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

plist_value() {
  local app_path="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$app_path/Contents/Info.plist" 2>/dev/null || true
}

plist_path_value() {
  local app_path="$1"
  local path="$2"
  /usr/libexec/PlistBuddy -c "Print $path" "$app_path/Contents/Info.plist" 2>/dev/null || true
}

print_section "Release Snapshot"
print_kv "Checked at" "$(date '+%Y-%m-%d %H:%M:%S %z')"
print_kv "Version file" "${EXPECTED_VERSION:-missing}"
print_kv "App target" "$APP_TARGET"
print_kv "Archive" "${ARCHIVE_PATH:-missing}"
print_kv "Checksum" "${CHECKSUM_PATH:-missing}"
print_kv "Release page" "https://github.com/passionate11/-/releases/latest"

print_section "Git"
if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
  STATUS="$(git -C "$ROOT_DIR" status --short 2>/dev/null || true)"
  TAG="v${EXPECTED_VERSION}"
  print_kv "Branch" "$BRANCH"
  print_kv "Commit" "$COMMIT"
  if [[ -z "$STATUS" ]]; then
    ok "Worktree"
  else
    warn "Worktree" "has uncommitted changes"
  fi
  if git -C "$ROOT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
    ok "Local tag $TAG"
  else
    warn "Local tag $TAG" "not found yet"
  fi
else
  warn "Git" "not a git worktree"
fi

print_section "Archive"
if [[ -n "$ARCHIVE_PATH" && -s "$ARCHIVE_PATH" ]]; then
  ok "Archive exists"
  ZIP_LIST="$(unzip -l "$ARCHIVE_PATH" 2>/dev/null || true)"
  if [[ "$ZIP_LIST" == *"Contents/MacOS/EyeRest"* ]]; then
    ok "Archive executable"
  else
    fail_check "Archive executable" "missing EyeRest binary"
  fi
  if [[ "$ZIP_LIST" == *"Contents/Resources/AppIcon.icns"* ]]; then
    ok "Archive icon"
  else
    fail_check "Archive icon" "missing AppIcon.icns"
  fi
  if [[ -n "$CHECKSUM_PATH" && -s "$CHECKSUM_PATH" ]]; then
    if (cd "$(dirname "$ARCHIVE_PATH")" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")" >/dev/null 2>&1); then
      ok "Archive checksum"
    else
      fail_check "Archive checksum" "sha256 file does not match archive"
    fi
  else
    fail_check "Archive checksum" "missing ${CHECKSUM_PATH:-checksum file}"
  fi
else
  fail_check "Archive exists" "run scripts/preflight_release.sh or scripts/package_app.sh first"
fi

print_section "App Bundle"
if [[ -d "$APP_TARGET" ]]; then
  INFO_PLIST="$APP_TARGET/Contents/Info.plist"
  EXECUTABLE_NAME="$(plist_value "$APP_TARGET" CFBundleExecutable)"
  EXECUTABLE_NAME="${EXECUTABLE_NAME:-EyeRest}"
  EXECUTABLE_PATH="$APP_TARGET/Contents/MacOS/$EXECUTABLE_NAME"
  BUNDLE_VERSION="$(plist_value "$APP_TARGET" CFBundleShortVersionString)"
  BUNDLE_BUILD="$(plist_value "$APP_TARGET" CFBundleVersion)"
  BUNDLE_ID="$(plist_value "$APP_TARGET" CFBundleIdentifier)"
  DISPLAY_NAME="$(plist_value "$APP_TARGET" CFBundleDisplayName)"
  URL_SCHEME="$(plist_path_value "$APP_TARGET" ':CFBundleURLTypes:0:CFBundleURLSchemes:0')"
  print_kv "Bundle id" "$BUNDLE_ID"
  print_kv "Display name" "$DISPLAY_NAME"
  print_kv "Version" "$BUNDLE_VERSION ($BUNDLE_BUILD)"
  print_kv "URL scheme" "$URL_SCHEME"
  if [[ -x "$EXECUTABLE_PATH" ]]; then
    ok "Executable"
  else
    fail_check "Executable" "missing or not executable"
  fi
  if [[ "$BUNDLE_VERSION" == "$EXPECTED_VERSION" ]]; then
    ok "Version match"
  else
    fail_check "Version match" "bundle=$BUNDLE_VERSION expected=$EXPECTED_VERSION"
  fi
  if [[ "$BUNDLE_ID" == "local.codex.eyerest" && "$DISPLAY_NAME" == "松一下" && "$URL_SCHEME" == "songyixia" ]]; then
    ok "Metadata"
  else
    fail_check "Metadata" "bundle id, display name, or URL scheme mismatch"
  fi
else
  fail_check "App bundle" "not found"
fi

print_section "Signing"
if [[ -d "$APP_TARGET" && "$(command -v codesign 2>/dev/null)" ]]; then
  VERIFY_OUTPUT="$(codesign --verify --deep --strict "$APP_TARGET" 2>&1)"
  VERIFY_STATUS="$?"
  if [[ "$VERIFY_STATUS" == "0" ]]; then
    ok "codesign verify"
  else
    fail_check "codesign verify" "$VERIFY_OUTPUT"
  fi
  CODESIGN_DETAILS="$(codesign -dv "$APP_TARGET" 2>&1 || true)"
  SIGNATURE="$(printf '%s\n' "$CODESIGN_DETAILS" | awk -F= '/Signature=/{print $2; exit}')"
  TEAM_ID="$(printf '%s\n' "$CODESIGN_DETAILS" | awk -F= '/TeamIdentifier=/{print $2; exit}')"
  print_kv "Signature" "${SIGNATURE:-unknown}"
  print_kv "TeamIdentifier" "${TEAM_ID:-not set}"
  if [[ "$SIGNATURE" == "adhoc" || -z "$TEAM_ID" || "$TEAM_ID" == "not set" ]]; then
    warn "Public distribution" "Developer ID signing and notarization not configured"
  else
    ok "Public distribution"
  fi
else
  fail_check "codesign verify" "codesign missing or app not found"
fi

if [[ -d "$APP_TARGET" && "$(command -v spctl 2>/dev/null)" ]]; then
  SPCTL_OUTPUT="$(spctl --assess --type execute "$APP_TARGET" 2>&1)"
  SPCTL_STATUS="$?"
  if [[ "$SPCTL_STATUS" == "0" ]]; then
    ok "Gatekeeper"
  else
    warn "Gatekeeper" "$SPCTL_OUTPUT"
  fi
fi

print_section "Release Flow"
if [[ -f "$ROOT_DIR/.github/workflows/release.yml" ]]; then
  ok "GitHub release workflow"
else
  fail_check "GitHub release workflow" "missing .github/workflows/release.yml"
fi
if [[ -f "$ROOT_DIR/scripts/preflight_release.sh" ]]; then
  ok "Preflight script"
else
  fail_check "Preflight script" "missing"
fi
if [[ -f "$ROOT_DIR/scripts/diagnose_app.sh" ]]; then
  ok "Diagnostics script"
else
  fail_check "Diagnostics script" "missing"
fi
warn "Auto update" "manual GitHub Release check is current plan; Sparkle remains future work"

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"
if [[ "$FAILURES" == "0" ]]; then
  print_kv "Readiness" "ready for current GitHub zip flow"
else
  print_kv "Readiness" "attention needed"
fi

if [[ "$STRICT" == "1" && "$FAILURES" != "0" ]]; then
  exit 1
fi
exit 0
