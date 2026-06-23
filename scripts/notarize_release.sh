#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION" 2>/dev/null || true)"
ARCHIVE_PATH="${ARCHIVE_PATH:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
NOTARIZE_SUBMIT="${NOTARIZE_SUBMIT:-0}"
WAIT_FOR_NOTARY="${WAIT_FOR_NOTARY:-1}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/notarize_release.sh
  ARCHIVE_PATH=dist/songyixia-0.1.44-1.zip scripts/notarize_release.sh
  NOTARIZE_SUBMIT=1 APPLE_ID=... APPLE_TEAM_ID=... APPLE_APP_PASSWORD=... scripts/notarize_release.sh

Default mode is a dry-run readiness check. It does not contact Apple.
Set NOTARIZE_SUBMIT=1 with Apple credentials to submit with notarytool.
HELP
  exit 0
fi

if [[ -z "$ARCHIVE_PATH" && -n "$EXPECTED_VERSION" ]]; then
  ARCHIVE_PATH="$(ls -t "$ROOT_DIR"/dist/songyixia-"$EXPECTED_VERSION"-*.zip 2>/dev/null | head -n 1 || true)"
fi

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

print_section "Notarization Readiness"
print_kv "Version file" "${EXPECTED_VERSION:-missing}"
print_kv "Archive" "${ARCHIVE_PATH:-missing}"
print_kv "Submit mode" "$([[ "$NOTARIZE_SUBMIT" == "1" ]] && echo submit || echo dry-run)"

if [[ -n "$ARCHIVE_PATH" && -s "$ARCHIVE_PATH" ]]; then
  ok "Archive exists"
else
  fail_check "Archive exists" "run scripts/preflight_release.sh first"
fi

if command -v xcrun >/dev/null 2>&1 && xcrun notarytool --help >/dev/null 2>&1; then
  ok "notarytool"
else
  fail_check "notarytool" "install full Xcode or Command Line Tools with notarytool"
fi

TMPDIR_NOTARY="$(mktemp -d "${TMPDIR:-/tmp}/songyixia-notary.XXXXXX")"
cleanup() {
  rm -rf "$TMPDIR_NOTARY"
}
trap cleanup EXIT

APP_PATH=""
if [[ -n "$ARCHIVE_PATH" && -s "$ARCHIVE_PATH" ]]; then
  if ditto -x -k "$ARCHIVE_PATH" "$TMPDIR_NOTARY" >/dev/null 2>&1; then
    APP_PATH="$(find "$TMPDIR_NOTARY" -maxdepth 2 -name "*.app" -type d | head -n 1 || true)"
    if [[ -n "$APP_PATH" ]]; then
      ok "Archive expands"
    else
      fail_check "Archive expands" "no .app bundle found in zip"
    fi
  else
    fail_check "Archive expands" "ditto could not extract zip"
  fi
fi

if [[ -n "$APP_PATH" ]]; then
  CODESIGN_VERIFY="$(codesign --verify --deep --strict "$APP_PATH" 2>&1)"
  CODESIGN_STATUS="$?"
  if [[ "$CODESIGN_STATUS" == "0" ]]; then
    ok "codesign verify"
  else
    fail_check "codesign verify" "$CODESIGN_VERIFY"
  fi

  CODESIGN_DETAILS="$(codesign -dv "$APP_PATH" 2>&1 || true)"
  SIGNATURE="$(printf '%s\n' "$CODESIGN_DETAILS" | awk -F= '/Signature=/{print $2; exit}')"
  TEAM_ID="$(printf '%s\n' "$CODESIGN_DETAILS" | awk -F= '/TeamIdentifier=/{print $2; exit}')"
  print_kv "Signature" "${SIGNATURE:-unknown}"
  print_kv "TeamIdentifier" "${TEAM_ID:-not set}"
  if [[ "$SIGNATURE" == "adhoc" || -z "$TEAM_ID" || "$TEAM_ID" == "not set" ]]; then
    warn "Developer ID" "archive is not signed for public notarized distribution yet"
  else
    ok "Developer ID"
  fi

  if spctl --assess --type execute "$APP_PATH" >/dev/null 2>&1; then
    ok "Gatekeeper"
  else
    warn "Gatekeeper" "expected to fail until Developer ID signing and notarization are configured"
  fi
fi

if [[ "$NOTARIZE_SUBMIT" == "1" ]]; then
  if [[ -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APPLE_APP_PASSWORD" ]]; then
    fail_check "Apple credentials" "set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD"
  else
    ok "Apple credentials"
  fi
else
  warn "Apple submission" "dry-run only; set NOTARIZE_SUBMIT=1 with Apple credentials to submit"
fi

print_section "Summary"
print_kv "Failures" "$FAILURES"
print_kv "Warnings" "$WARNINGS"

if [[ "$FAILURES" != "0" ]]; then
  print_kv "Notarization" "attention needed"
  exit 1
fi

if [[ "$NOTARIZE_SUBMIT" != "1" ]]; then
  print_kv "Notarization" "ready for dry-run plan"
  exit 0
fi

SUBMIT_ARGS=("$ARCHIVE_PATH" "--apple-id" "$APPLE_ID" "--team-id" "$APPLE_TEAM_ID" "--password" "$APPLE_APP_PASSWORD")
if [[ "$WAIT_FOR_NOTARY" == "1" ]]; then
  SUBMIT_ARGS+=("--wait")
fi

print_section "Submitting"
xcrun notarytool submit "${SUBMIT_ARGS[@]}"
NOTARY_STATUS="$?"
if [[ "$NOTARY_STATUS" != "0" ]]; then
  exit "$NOTARY_STATUS"
fi

print_section "Staple Note"
print_kv "Stapling" "zip submission accepted; staple the extracted .app before rebuilding final zip when using public distribution"
