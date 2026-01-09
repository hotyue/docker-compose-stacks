#!/usr/bin/env bash
set -euo pipefail

# =========================
# Installer Global Settings
# =========================
export TZ=UTC
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED_FILE="$REPO_ROOT/.installed"

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[$(timestamp)] 缺少命令：$1"
    exit 1
  }
}

ensure_network() {
  local net="${1:-}"
  [ -z "$net" ] && return 0
  if ! docker network inspect "$net" >/dev/null 2>&1; then
    echo "[$(timestamp)] 创建 Docker 网络：$net"
    docker network create "$net" >/dev/null
  fi
}

is_installed() {
  local dir="$1"
  [ -f "$INSTALLED_FILE" ] && grep -Fxq "$dir" "$INSTALLED_FILE"
}

mark_installed() {
  local dir="$1"
  mkdir -p "$(dirname "$INSTALLED_FILE")"
  touch "$INSTALLED_FILE"
  grep -Fxq "$dir" "$INSTALLED_FILE" || echo "$dir" >> "$INSTALLED_FILE"
}

install_stack() {
  local dir="$1"

  # shellcheck disable=SC1090
  source "$dir/stack.meta"

  echo
  echo "即将安装："
  echo "  名称        ：$NAME"
  echo "  分类        ：$CATEGORY"
  echo "  描述        ：$DESCRIPTION"
  echo "  目录        ：$dir"
  echo "  依赖网络    ：${REQUIRES_NETWORK:-无}"
  echo

  read -r -p "确认安装？[y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "[$(timestamp)] 已取消安装。"
    exit 0
  fi

  # env 处理
  if [ -f "$dir/.env.example" ] && [ ! -f "$dir/.env" ]; then
    cp "$dir/.env.example" "$dir/.env"
    echo "[$(timestamp)] 已生成 .env（来自 .env.example）"
  fi

  # 网络处理
  ensure_network "${REQUIRES_NETWORK:-}"

  echo "[$(timestamp)] 启动服务中..."
  (cd "$dir" && docker compose up -d)

  mark_installed "$dir"
  echo "[$(timestamp)] 安装完成：$NAME"
}

main() {
  need_cmd docker
  need_cmd find

  mapfile -t METAS < <(find "$REPO_ROOT/stacks" -type f -name stack.meta 2>/dev/null | sort)
  if [ "${#METAS[@]}" -eq 0 ]; then
    echo "[$(timestamp)] 未找到任何 stack.meta"
    exit 1
  fi

  declare -a DIRS LINES
  for meta in "${METAS[@]}"; do
    local dir NAME CATEGORY DESCRIPTION REQUIRES_NETWORK
    dir="$(dirname "$meta")"
    NAME=""; CATEGORY=""; DESCRIPTION=""; REQUIRES_NETWORK=""
    # shellcheck disable=SC1090
    source "$meta"

    local extra=""
    [ -n "${REQUIRES_NETWORK:-}" ] && extra="needs:${REQUIRES_NETWORK}"
    is_installed "$dir" && extra="$extra 已安装"

    DIRS+=("$dir")
    LINES+=("[$CATEGORY] $NAME - $DESCRIPTION ${extra:+($extra)}")
  done

  echo
  echo "可安装应用栈："
  for i in "${!LINES[@]}"; do
    printf "%3d) %s\n" "$((i+1))" "${LINES[$i]}"
  done
  echo "  0) 退出"
  echo

  read -r -p "请输入编号： " choice
  if [ "$choice" = "0" ]; then
    echo "[$(timestamp)] 已退出。"
    exit 0
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#DIRS[@]}" ]; then
    echo "[$(timestamp)] 无效选择：$choice"
    exit 1
  fi

  local target="${DIRS[$((choice-1))]}"
  if is_installed "$target"; then
    echo "[$(timestamp)] 该应用已安装，如需重装请先手动清理。"
    exit 0
  fi

  install_stack "$target"
}

main "$@"
