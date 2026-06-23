#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_PATH="${OUTPUT_PATH:-$DIST_DIR/release-notes-${VERSION}.md}"
ARCHIVE_PATH="${ARCHIVE_PATH:-}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "${LC_ALL:-}" == "C.UTF-8" ]] && export LC_ALL="en_US.UTF-8"
  [[ "${LC_CTYPE:-}" == "C.UTF-8" ]] && export LC_CTYPE="en_US.UTF-8"
  [[ "${LANG:-}" == "C.UTF-8" || -z "${LANG:-}" ]] && export LANG="en_US.UTF-8"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/generate_release_notes.sh
  OUTPUT_PATH=dist/release-notes-0.1.44.md scripts/generate_release_notes.sh

Generates concise GitHub Release notes for 松一下 from CHANGELOG.md and dist artifacts.
HELP
  exit 0
fi

if [[ -z "$ARCHIVE_PATH" ]]; then
  ARCHIVE_PATH="$(ls -t "$DIST_DIR"/songyixia-"$VERSION"-*.zip 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$ARCHIVE_PATH" || ! -s "$ARCHIVE_PATH" ]]; then
  echo "generate_release_notes: release zip missing; run scripts/preflight_release.sh first" >&2
  exit 1
fi

CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
if [[ ! -s "$CHECKSUM_PATH" ]]; then
  echo "generate_release_notes: checksum missing: $CHECKSUM_PATH" >&2
  exit 1
fi

ARCHIVE_NAME="$(basename "$ARCHIVE_PATH")"
CHECKSUM_NAME="$(basename "$CHECKSUM_PATH")"
SHA256_VALUE="$(awk '{print $1; exit}' "$CHECKSUM_PATH")"
MAIN_CHANGES="$(awk '
  /^## main$/ {in_main=1; next}
  /^## / && in_main {exit}
  in_main && /^- / {print}
' "$ROOT_DIR/CHANGELOG.md")"
if [[ -z "$MAIN_CHANGES" ]]; then
  MAIN_CHANGES="- 维护更新。"
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
cat > "$OUTPUT_PATH" <<NOTES
# 松一下 ${VERSION}

## 下载

- \`${ARCHIVE_NAME}\`
- \`${CHECKSUM_NAME}\`

SHA256:

\`\`\`text
${SHA256_VALUE}  ${ARCHIVE_NAME}
\`\`\`

## 安装

1. 下载并解压 \`${ARCHIVE_NAME}\`。
2. 把 \`松一下.app\` 拖入 \`/Applications\` 覆盖旧版本。
3. 打开菜单栏「关于 松一下...」确认版本，或用「检查更新...」查看当前版本。
4. 如果 macOS 提示来自未验证开发者，可以在 Finder 里右键打开，或到系统设置里允许打开。

## 本次更新

${MAIN_CHANGES}

## 反馈

遇到卡住、置顶、计时、外接屏或更新问题时，先在菜单栏「排查中心」复制问题反馈包，再打开 GitHub Issue：

https://github.com/passionate11/-/issues/new
NOTES

echo "$OUTPUT_PATH"
