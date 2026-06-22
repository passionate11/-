#!/usr/bin/env bash
set -u

APP_TARGET="${APP_TARGET:-/Applications/松一下.app}"
BUNDLE_ID="${BUNDLE_ID:-local.codex.eyerest}"
URL_SCHEME="${URL_SCHEME:-songyixia}"
WINDOW_LIST_TOOL="${WINDOW_LIST_TOOL:-/tmp/list_windows}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/diagnose_app.sh
  APP_TARGET=outputs/EyeRest.app scripts/diagnose_app.sh

Prints a local diagnostic snapshot for 松一下 without changing app state.
HELP
  exit 0
fi

if [[ -n "${1:-}" ]]; then
  APP_TARGET="$1"
fi

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

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$APP_TARGET/Contents/Info.plist" 2>/dev/null || true
}

plist_path_value() {
  local path="$1"
  /usr/libexec/PlistBuddy -c "Print $path" "$APP_TARGET/Contents/Info.plist" 2>/dev/null || true
}

print_section "Bundle"
print_kv "Checked at" "$(date '+%Y-%m-%d %H:%M:%S %z')"
print_kv "App path" "$APP_TARGET"

if [[ ! -d "$APP_TARGET" ]]; then
  print_kv "Exists" "no"
  echo "diagnose_app: app bundle was not found" >&2
  exit 1
fi

INFO_PLIST="$APP_TARGET/Contents/Info.plist"
EXECUTABLE_NAME="$(plist_value CFBundleExecutable)"
if [[ -z "$EXECUTABLE_NAME" ]]; then
  EXECUTABLE_NAME="EyeRest"
fi
EXECUTABLE_PATH="$APP_TARGET/Contents/MacOS/$EXECUTABLE_NAME"
ICON_FILE="$(plist_value CFBundleIconFile)"

print_kv "Exists" "yes"
print_kv "Bundle id" "$(plist_value CFBundleIdentifier)"
print_kv "Display name" "$(plist_value CFBundleDisplayName)"
print_kv "Version" "$(plist_value CFBundleShortVersionString)"
print_kv "Build" "$(plist_value CFBundleVersion)"
print_kv "Executable" "$EXECUTABLE_PATH"
print_kv "Executable exists" "$([[ -x "$EXECUTABLE_PATH" ]] && echo yes || echo no)"
print_kv "Icon" "$([[ -n "$ICON_FILE" ]] && echo "$APP_TARGET/Contents/Resources/$ICON_FILE.icns" || echo "-")"
print_kv "URL scheme" "$(plist_path_value ':CFBundleURLTypes:0:CFBundleURLSchemes:0')"

print_section "Signature"
if command -v codesign >/dev/null 2>&1; then
  VERIFY_OUTPUT="$(codesign --verify --deep --strict "$APP_TARGET" 2>&1)"
  VERIFY_STATUS="$?"
  if [[ "$VERIFY_STATUS" == "0" ]]; then
    print_kv "codesign verify" "ok"
  else
    print_kv "codesign verify" "failed"
    printf '%s\n' "$VERIFY_OUTPUT" | sed 's/^/    /'
  fi
  CODESIGN_DETAILS="$(codesign -dv "$APP_TARGET" 2>&1 || true)"
  printf '%s\n' "$CODESIGN_DETAILS" \
    | awk -F= '/Identifier=|Signature=|TeamIdentifier=/{printf "  %-24s %s\n", $1 ":", $2}'
else
  print_kv "codesign verify" "codesign not found"
fi

if command -v xattr >/dev/null 2>&1; then
  QUARANTINE="$(xattr -p com.apple.quarantine "$APP_TARGET" 2>/dev/null || true)"
  print_kv "Quarantine" "${QUARANTINE:-none}"
fi

print_section "Process"
PROCESS_LINES="$(pgrep -fl "$EXECUTABLE_PATH" 2>/dev/null || true)"
PROCESS_COUNT="$(printf '%s\n' "$PROCESS_LINES" | sed '/^$/d' | wc -l | tr -d ' ')"
print_kv "Process count" "$PROCESS_COUNT"
if [[ -n "$PROCESS_LINES" ]]; then
  printf '%s\n' "$PROCESS_LINES" | sed 's/^/  /'
fi

ALL_EYEREST_LINES="$(pgrep -fl "$EXECUTABLE_NAME" 2>/dev/null | grep '/Contents/MacOS/' || true)"
ALL_EYEREST_COUNT="$(printf '%s\n' "$ALL_EYEREST_LINES" | sed '/^$/d' | wc -l | tr -d ' ')"
print_kv "All EyeRest-like" "$ALL_EYEREST_COUNT"
if [[ "$ALL_EYEREST_COUNT" != "$PROCESS_COUNT" && -n "$ALL_EYEREST_LINES" ]]; then
  printf '%s\n' "$ALL_EYEREST_LINES" | sed 's/^/  /'
fi

LOCK_PATH="/tmp/local.codex.eyerest.lock"
print_kv "Single lock file" "$([[ -e "$LOCK_PATH" ]] && echo "$LOCK_PATH" || echo "missing")"

print_section "Preferences"
if /usr/bin/defaults read "$BUNDLE_ID" >/dev/null 2>&1; then
  print_kv "Defaults domain" "$BUNDLE_ID"
  for key in eyeEnabled eyeFocusSeconds eyeRestSeconds standEnabled standIntervalSeconds standDurationSeconds restStyle menuBarMode showRestWindow notificationsEnabled; do
    VALUE="$(/usr/bin/defaults read "$BUNDLE_ID" "$key" 2>/dev/null || true)"
    if [[ -n "$VALUE" ]]; then
      print_kv "$key" "$VALUE"
    fi
  done
  RECOVERY_HISTORY="$(/usr/bin/defaults read "$BUNDLE_ID" recoveryHistory 2>/dev/null || true)"
  if [[ -n "$RECOVERY_HISTORY" ]]; then
    printf '\n  recent recoveryHistory:\n'
    printf '%s\n' "$RECOVERY_HISTORY" | tail -40 | sed 's/^/    /'
  fi
else
  print_kv "Defaults domain" "missing"
fi

print_section "Windows"
if [[ -x "$WINDOW_LIST_TOOL" ]]; then
  print_kv "Source" "$WINDOW_LIST_TOOL"
  WINDOW_LINES="$("$WINDOW_LIST_TOOL" 2>&1 | awk '
    /^[[:space:]]*[{]/ {
      in_block = 1
      block = $0 "\n"
      hit = 0
      next
    }
    in_block {
      block = block $0 "\n"
      if ($0 ~ /kCGWindowOwnerName/ && ($0 ~ /松一下/ || $0 ~ /[\\]U677e[\\]U4e00[\\]U4e0b/)) {
        hit = 1
      }
      if ($0 ~ /^[[:space:]]*[}]/) {
        if (hit) {
          n = split(block, lines, "\n")
          for (i = 1; i <= n; i++) {
            if (lines[i] ~ /kCGWindow(Number|OwnerName|Name|Layer|IsOnscreen|Bounds)/) {
              print "  " lines[i]
            }
          }
          print ""
        }
        in_block = 0
        block = ""
        hit = 0
      }
    }
  ')"
  if [[ -n "$WINDOW_LINES" ]]; then
    printf '%s\n' "$WINDOW_LINES"
  else
    print_kv "松一下 windows" "none visible"
  fi
else
  print_kv "Source" "$WINDOW_LIST_TOOL missing"
fi
