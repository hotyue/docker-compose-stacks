#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "缺少命令：$1"; exit 1; }; }

ensure_network() {
  local net="${1:-}"
  [ -z "$net" ] && return 0
  if ! docker network inspect "$net" >/dev/null 2>&1; then
    echo "创建 Docker 网络：$net"
    docker network create "$net" >/dev/null
  fi
}

install_stack() {
  local dir="$1"
  echo "开始安装：$dir"

  # .env 处理
  if [ -f "$dir/.env.example" ] && [ ! -f "$dir/.env" ]; then
    cp "$dir/.env.example" "$dir/.env"
    echo "已生成：$dir/.env（来自 .env.example）"
  fi

  # 读取 meta
  local NAME CATEGORY DESCRIPTION REQUIRES_NETWORK DEFAULT_ENABLE
  NAME=""; CATEGORY=""; DESCRIPTION=""; REQUIRES_NETWORK=""; DEFAULT_ENABLE=""
  # shellcheck disable=SC1090
  source "$dir/stack.meta"

  # 网络处理
  ensure_network "${REQUIRES_NETWORK:-}"

  # 启动
  (cd "$dir" && docker compose up -d)
  echo "安装完成：${NAME:-$dir}"
}

main() {
  need_cmd docker
  need_cmd awk

  # 收集 stack.meta：支持 stacks/<name>/ 与 stacks/<name>/<sub>/
  mapfile -t METAS < <(find "$REPO_ROOT/stacks" -type f -name stack.meta 2>/dev/null | sort)
  if [ "${#METAS[@]}" -eq 0 ]; then
    echo "未找到任何 stack.meta（请确认 stacks 目录下已存在应用栈）。"
    exit 1
  fi

  # 构建菜单
  declare -a DIRS LINES
  local i=0
  for meta in "${METAS[@]}"; do
    local dir; dir="$(dirname "$meta")"
    local NAME CATEGORY DESCRIPTION
    NAME=""; CATEGORY=""; DESCRIPTION=""
    # shellcheck disable=SC1090
    source "$meta"
    DIRS+=("$dir")
    LINES+=("[$CATEGORY] $NAME - $DESCRIPTION")
    i=$((i+1))
  done

  echo "可安装应用栈："
  for idx in "${!LINES[@]}"; do
    printf "%3d) %s\n" "$((idx+1))" "${LINES[$idx]}"
  done
  echo "  0) 退出"

  printf "请输入编号："
  read -r choice

  if [ "$choice" = "0" ]; then
    echo "已退出。"
    exit 0
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#DIRS[@]}" ]; then
    echo "无效选择：$choice"
    exit 1
  fi

  install_stack "${DIRS[$((choice-1))]}"
}

main "$@"
