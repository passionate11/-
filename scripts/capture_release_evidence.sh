#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$ROOT_DIR/outputs/EyeRest.app"
APP_INSTALLED="${APP_INSTALLED:-/Applications/松一下.app}"
VERSION_FILE="$ROOT_DIR/VERSION"
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || true)"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/songyixia-release-evidence.XXXXXX")"
FAILURES=0
STATUS_LINES=""

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "${LC_ALL:-}" == "C.UTF-8" ]] && export LC_ALL="en_US.UTF-8"
  [[ "${LC_CTYPE:-}" == "C.UTF-8" ]] && export LC_CTYPE="en_US.UTF-8"
  [[ "${LANG:-}" == "C.UTF-8" || -z "${LANG:-}" ]] && export LANG="en_US.UTF-8"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/capture_release_evidence.sh
  APP_INSTALLED=/Applications/松一下.app scripts/capture_release_evidence.sh

Builds the release zip, runs the low-disruption release/readiness checks, and writes
a timestamped evidence bundle under dist/release-evidence-<version>-<build>-<time>.
It does not run the full-screen smoke test.
HELP
  exit 0
fi

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

run_capture() {
  local label="$1"
  shift
  local output="$TEMP_DIR/$label.txt"
  local status=0
  {
    printf 'releaseEvidenceCommand=%s\n' "$label"
    printf 'startedAt=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'command='
    printf '%q ' "$@"
    printf '\n\n'
    set +e
    "$@"
    status="$?"
    set -e
    printf '\nexitStatus=%s\n' "$status"
    printf 'finishedAt=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  } >"$output" 2>&1

  if [[ "$status" == "0" ]]; then
    STATUS_LINES="${STATUS_LINES}${label}=ok"$'\n'
  else
    STATUS_LINES="${STATUS_LINES}${label}=fail(${status})"$'\n'
    FAILURES=$((FAILURES + 1))
  fi
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

write_manifest_json() {
  local output="$1"
  local release_notes_path="$2"
  local archive_sha256="$3"
  {
    printf '{\n'
    printf '  "releaseEvidence": true,\n'
    printf '  "generatedAt": "%s",\n' "$(json_escape "$(date '+%Y-%m-%d %H:%M:%S %z')")"
    printf '  "version": "%s",\n' "$(json_escape "${VERSION:-unknown}")"
    printf '  "build": "%s",\n' "$(json_escape "${BUILD:-unknown}")"
    printf '  "repository": "%s",\n' "$(json_escape "$ROOT_DIR")"
    printf '  "appBundle": "%s",\n' "$(json_escape "$APP_BUNDLE")"
    printf '  "installedApp": "%s",\n' "$(json_escape "$APP_INSTALLED")"
    printf '  "archive": "%s",\n' "$(json_escape "${ARCHIVE_PATH:-missing}")"
    printf '  "checksum": "%s",\n' "$(json_escape "${CHECKSUM_PATH:-missing}")"
    printf '  "archiveSha256": "%s",\n' "$(json_escape "${archive_sha256:-missing}")"
    printf '  "releaseNotes": "%s",\n' "$(json_escape "${release_notes_path:-missing}")"
    printf '  "doesNotRun": "full-screen smoke test",\n'
    printf '  "failures": %s,\n' "$FAILURES"
    printf '  "commands": [\n'
    local first=1
    while IFS='=' read -r label status; do
      [[ -z "$label" ]] && continue
      if [[ "$first" == "1" ]]; then
        first=0
      else
        printf ',\n'
      fi
      printf '    {"label": "%s", "status": "%s", "file": "%s.txt"}' \
        "$(json_escape "$label")" \
        "$(json_escape "$status")" \
        "$(json_escape "$label")"
    done <<< "$STATUS_LINES"
    printf '\n  ]\n'
    printf '}\n'
  } > "$output"
}

write_evidence_checklist() {
  local output="$1"
  local release_notes_path="$2"
  local archive_sha256="$3"
  {
    printf '# Release Evidence Checklist\n\n'
    printf -- '- version: %s\n' "${VERSION:-unknown}"
    printf -- '- build: %s\n' "${BUILD:-unknown}"
    printf -- '- generatedAt: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf -- '- doesNotRun: full-screen smoke test\n\n'
    printf '## Required Artifacts\n\n'
    printf -- '- [%s] archive: %s\n' "$([[ -n "${ARCHIVE_PATH:-}" && -f "$ARCHIVE_PATH" ]] && echo x || echo ' ')" "${ARCHIVE_PATH:-missing}"
    printf -- '- [%s] checksum: %s\n' "$([[ -n "${CHECKSUM_PATH:-}" && -f "$CHECKSUM_PATH" ]] && echo x || echo ' ')" "${CHECKSUM_PATH:-missing}"
    printf -- '- [%s] archiveSha256: %s\n' "$([[ -n "$archive_sha256" ]] && echo x || echo ' ')" "${archive_sha256:-missing}"
    printf -- '- [%s] releaseNotes: %s\n' "$([[ -n "$release_notes_path" && -f "$release_notes_path" ]] && echo x || echo ' ')" "${release_notes_path:-missing}"
    printf -- '- [x] manifest.txt\n'
    printf -- '- [x] manifest.json\n\n'
    printf '## Command Captures\n\n'
    while IFS='=' read -r label status; do
      [[ -z "$label" ]] && continue
      local check=' '
      [[ "$status" == "ok" ]] && check='x'
      printf -- '- [%s] %s: %s (`%s.txt`)\n' "$check" "$label" "$status" "$label"
    done <<< "$STATUS_LINES"
    printf '\n## Summary\n\n'
    printf -- '- failures: %s\n' "$FAILURES"
  } > "$output"
}

cd "$ROOT_DIR"

run_capture "git_status" git -C "$ROOT_DIR" status --short --branch
run_capture "git_log" git -C "$ROOT_DIR" log -5 --oneline
run_capture "preflight_release" "$ROOT_DIR/scripts/preflight_release.sh"

BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true)"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true)}"
ARCHIVE_PATH="$(ls -t "$DIST_DIR"/songyixia-"$VERSION"-*.zip 2>/dev/null | head -n 1 || true)"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

run_capture "release_readiness" env APP_TARGET="$APP_BUNDLE" ARCHIVE_PATH="$ARCHIVE_PATH" "$ROOT_DIR/scripts/release_readiness.sh" --strict
run_capture "auto_update_readiness" env APP_TARGET="$APP_BUNDLE" ARCHIVE_PATH="$ARCHIVE_PATH" "$ROOT_DIR/scripts/auto_update_readiness.sh" --strict
run_capture "roadmap_status" "$ROOT_DIR/scripts/roadmap_status.sh" --strict
run_capture "settings_visual_readiness" "$ROOT_DIR/scripts/settings_visual_readiness.sh" --strict
run_capture "automation_keyword_config_readiness" "$ROOT_DIR/scripts/automation_keyword_config_readiness.sh" --strict
run_capture "automation_policy_readiness" "$ROOT_DIR/scripts/automation_policy_readiness.sh" --strict
run_capture "release_evidence_readiness" "$ROOT_DIR/scripts/release_evidence_readiness.sh" --strict
run_capture "settings_contract_readiness" "$ROOT_DIR/scripts/settings_contract_readiness.sh" --strict
run_capture "swiftui_migration_readiness" "$ROOT_DIR/scripts/swiftui_migration_readiness.sh" --strict
run_capture "swiftui_parity_plan" "$ROOT_DIR/scripts/swiftui_parity_plan.sh" --strict
run_capture "diagnose_installed_app" env APP_TARGET="$APP_INSTALLED" "$ROOT_DIR/scripts/diagnose_app.sh"

mkdir -p "$DIST_DIR"
EVIDENCE_DIR="${EVIDENCE_DIR:-$DIST_DIR/release-evidence-${VERSION:-unknown}-${BUILD:-unknown}-$TIMESTAMP}"
mkdir -p "$EVIDENCE_DIR"
cp "$TEMP_DIR"/*.txt "$EVIDENCE_DIR/"

RELEASE_NOTES="$DIST_DIR/release-notes-${VERSION}.md"
[[ -f "$RELEASE_NOTES" ]] && cp "$RELEASE_NOTES" "$EVIDENCE_DIR/"
[[ -n "$ARCHIVE_PATH" && -f "$ARCHIVE_PATH" ]] && /usr/bin/shasum -a 256 "$ARCHIVE_PATH" > "$EVIDENCE_DIR/archive.sha256"
[[ -n "$CHECKSUM_PATH" && -f "$CHECKSUM_PATH" ]] && cp "$CHECKSUM_PATH" "$EVIDENCE_DIR/"
ARCHIVE_SHA256=""
if [[ -n "$CHECKSUM_PATH" && -f "$CHECKSUM_PATH" ]]; then
  ARCHIVE_SHA256="$(awk '{print $1; exit}' "$CHECKSUM_PATH")"
elif [[ -n "$ARCHIVE_PATH" && -f "$ARCHIVE_PATH" ]]; then
  ARCHIVE_SHA256="$(/usr/bin/shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1; exit}')"
fi

cat > "$EVIDENCE_DIR/manifest.txt" <<MANIFEST
releaseEvidence=1
generatedAt=$(date '+%Y-%m-%d %H:%M:%S %z')
version=${VERSION:-unknown}
build=${BUILD:-unknown}
repository=$ROOT_DIR
appBundle=$APP_BUNDLE
installedApp=$APP_INSTALLED
archive=${ARCHIVE_PATH:-missing}
checksum=${CHECKSUM_PATH:-missing}
doesNotRun=full-screen smoke test
status:
$STATUS_LINES
failures=$FAILURES
MANIFEST

write_manifest_json "$EVIDENCE_DIR/manifest.json" "$RELEASE_NOTES" "$ARCHIVE_SHA256"
write_evidence_checklist "$EVIDENCE_DIR/evidence-checklist.md" "$RELEASE_NOTES" "$ARCHIVE_SHA256"

printf 'Release evidence captured: %s\n' "$EVIDENCE_DIR"
printf 'Failures: %s\n' "$FAILURES"

if [[ "$FAILURES" != "0" ]]; then
  exit 1
fi
