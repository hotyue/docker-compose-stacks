#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACKS_DIR="$REPO_ROOT/stacks"
README="$REPO_ROOT/README.md"

START_MARK="<!-- STACKS:START -->"
END_MARK="<!-- STACKS:END -->"

# 防止变量污染
unset GROUPS
declare -A GROUPS

# 分类顺序（冻结）
CATEGORIES=(
  reverse-proxy
  monitoring
  database
  cache
  message-queue
  storage
  security
  utility
)

# 分类显示名（中文）
declare -A CAT_TITLES=(
  [reverse-proxy]="反向代理"
  [monitoring]="监控"
  [database]="数据库"
  [cache]="缓存"
  [message-queue]="消息队列"
  [storage]="存储"
  [security]="安全"
  [utility]="工具"
)

# 扫描 stack.meta
while IFS= read -r meta; do
  NAME=""
  CATEGORY=""
  DESCRIPTION=""

  # shellcheck disable=SC1090
  source "$meta"

  [ -z "$NAME" ] && continue
  [ -z "$CATEGORY" ] && continue

  entry="- **${NAME}**  \n  ${DESCRIPTION}\n"
  GROUPS["$CATEGORY"]+="$entry"

done < <(find "$STACKS_DIR" -type f -name stack.meta | sort)

# 生成 Markdown
OUTPUT=""
for cat in "${CATEGORIES[@]}"; do
  if [ -n "${GROUPS[$cat]:-}" ]; then
    title="${CAT_TITLES[$cat]:-$cat}"
    OUTPUT+="\n### ${title}\n\n"
    OUTPUT+="${GROUPS[$cat]}"
  fi
done

# 写入 README（仅替换锚点内）
awk -v start="$START_MARK" -v end="$END_MARK" -v body="$OUTPUT" '
  $0 == start { print; print body; skip=1; next }
  $0 == end   { skip=0 }
  !skip
' "$README" > "$README.tmp"

mv "$README.tmp" "$README"

echo "Stacks 索引已更新。"
