#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Docker Compose Stacks Installer (v1.3.0)
# ==============================================================================
# 核心安装脚本，负责：
# 1. 依赖环境检测
# 2. Stack 资源同步（物理复制）
# 3. 环境变量 (.env) 交互式生成
# 4. 通用生命周期钩子执行 (Lifecycle Hooks)
# 5. 容器启动与智能清理
# ==============================================================================

# -------------------------
# 全局设置 (Global Settings)
# -------------------------
export TZ=UTC
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED_FILE="$REPO_ROOT/.installed"
PENDING_FILE="$REPO_ROOT/.installing"

# -------------------------
# 运行时布局 (Runtime Layout)
# -------------------------
RUNTIME_ROOT="/opt/docker"

# -------------------------
# 加载依赖库 (Library Loading)
# -------------------------
# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/lib/runtime.sh"

# 检测 docker compose 命令 (docker compose vs docker-compose)
detect_compose

# ==============================================================================
# 辅助函数 (Helper Functions)
# ==============================================================================

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# 检查命令是否存在，不存在则退出
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[$(timestamp)] ERROR: 缺少必要命令：$1"
    exit 1
  }
}

# 计算 Stack 的运行时路径
runtime_dir_for_stack() {
  local stack_dir="$1"
  local rel
  rel="${stack_dir#"$REPO_ROOT/stacks/"}"
  echo "$RUNTIME_ROOT/$rel"
}

# 创建并赋予目录权限
prepare_runtime_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    echo "[$(timestamp)] 创建运行目录：$dir"
    mkdir -p "$dir"
  fi
  chmod 775 "$dir"
}

# 确保 Docker 网络存在
ensure_network() {
  local net="${1:-}"
  [ -z "$net" ] && return 0
  if ! docker network inspect "$net" >/dev/null 2>&1; then
    echo "[$(timestamp)] 创建 Docker 网络：$net"
    docker network create "$net" >/dev/null
  fi
}

# 检查是否已安装
is_installed() {
  local dir="$1"
  [ -f "$INSTALLED_FILE" ] && grep -Fxq "$dir" "$INSTALLED_FILE"
}

# 标记为已安装
mark_installed() {
  local dir="$1"
  mkdir -p "$(dirname "$INSTALLED_FILE")"
  touch "$INSTALLED_FILE"
  grep -Fxq "$dir" "$INSTALLED_FILE" || echo "$dir" >> "$INSTALLED_FILE"
}

# ==============================================================================
# 核心逻辑：资源同步 (Stack Asset Sync)
# ==============================================================================
sync_stack_assets() {
  local src_dir="$1"
  local runtime_dir="$2"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude 'stack.meta' \
      --exclude '.env.example' \
      --exclude '.git' \
      --exclude '.gitignore' \
      --exclude '.github' \
      --exclude '.DS_Store' \
      --exclude '.env' \
      --exclude 'hooks' \
      "$src_dir/" "$runtime_dir/"
  else
    local item
    shopt -s dotglob nullglob
    for item in "$src_dir"/* "$src_dir"/.*; do
      case "$(basename "$item")" in
        "."|".."|"stack.meta"|".env.example"|".env"|".git"|".github"|".gitignore"|".DS_Store"|"hooks")
          continue
          ;;
      esac
      if [ ! -e "$runtime_dir/$(basename "$item")" ]; then
        cp -a "$item" "$runtime_dir/" 2>/dev/null || true
      fi
    done
    shopt -u dotglob nullglob
  fi
}

# ==============================================================================
# 核心逻辑：安装 Stack (Install Stack)
# ==============================================================================
install_stack() {
  local dir="$1"

  # 加载 Stack 元数据
  # shellcheck disable=SC1090
  source "$dir/stack.meta"

  local runtime_dir
  runtime_dir="$(runtime_dir_for_stack "$dir")"

  echo
  echo "即将安装："
  echo "  名称        ：$NAME"
  echo "  分类        ：$CATEGORY"
  echo "  描述        ：$DESCRIPTION"
  echo "  定义目录    ：$dir"
  echo "  运行目录    ：$runtime_dir"
  echo "  依赖网络    ：${REQUIRES_NETWORK:-无}"
  echo

  read -r -p "确认安装？[y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "[$(timestamp)] 已取消安装。"
    exit 0
  fi

  # 1. 准备环境
  prepare_runtime_dir "$runtime_dir"
  ensure_network "${REQUIRES_NETWORK:-}"

  # 2. 同步资源 (物理复制)
  sync_stack_assets "$dir" "$runtime_dir"

  # 3. 处理 .env 配置
  ENV_CREATED=false
  if [ -f "$dir/.env.example" ] && [ ! -f "$runtime_dir/.env" ]; then
    cp "$dir/.env.example" "$runtime_dir/.env"
    ENV_CREATED=true
    echo "[$(timestamp)] 已生成运行目录 .env（来自 .env.example）"
  fi

  if [ -f "$dir/.env.example" ] && [ -f "$runtime_dir/.env" ]; then
    required_keys=$(grep -Ev '^\s*#|^\s*$' "$dir/.env.example" | grep '=' | grep -v '=$' | cut -d= -f1)
    for key in $required_keys; do
      if ! grep -q "^$key=" "$runtime_dir/.env"; then
        echo "[$(timestamp)] ERROR: 缺少必填配置项 '$key'（.env）"
        exit 1
      fi
      value=$(grep "^$key=" "$runtime_dir/.env" | cut -d= -f2-)
      if [ -z "$value" ]; then
        echo "[$(timestamp)] ERROR: 必填配置项 '$key' 为空（.env）"
        exit 1
      fi
    done
  fi

  # 4. 中断保护
  if [ "$ENV_CREATED" = true ]; then
    {
      echo "STACK_DIR=$dir"
      echo "RUNTIME_DIR=$runtime_dir"
    } > "$PENDING_FILE"
    echo "--------------------------------------------------"
    echo "已生成配置文件： $runtime_dir/.env"
    echo "修改完成后，重新运行 installer 将继续安装。"
    echo "--------------------------------------------------"
    exit 0
  fi

  # 5. 通用预处理钩子 (Generic Pre-install Hook)
  local hook_script="$dir/hooks/pre-install.sh"
  if [ -f "$hook_script" ] && [ -x "$hook_script" ]; then
    echo "[$(timestamp)] 检测到预处理钩子，正在执行..."
    export RUNTIME_DIR="$runtime_dir"
    export STACK_DIR="$dir"
    "$hook_script" || { echo "[$(timestamp)] ERROR: 钩子执行失败！"; exit 1; }
  fi

  # 6. 启动服务与智能清理
  echo "[$(timestamp)] 启动服务中..."
  (
    cd "$runtime_dir"
    $COMPOSE_CMD up -d
    echo "[$(timestamp)] 检查并清理初始化容器..."
    sleep 3
    stopped_containers=$($COMPOSE_CMD ps -a --filter "status=exited" -q)
    if [ -n "$stopped_containers" ]; then
      for container_id in $stopped_containers; do
        exit_code=$(docker inspect "$container_id" --format='{{.State.ExitCode}}')
        if [ "$exit_code" == "0" ]; then
           echo "  - 清理成功完成的任务容器: $container_id"
           docker rm "$container_id" >/dev/null
        else
           echo "  ! 警告: 容器 $container_id 异常退出 (Code: $exit_code)，已保留用于调试。"
        fi
      done
    fi  
  )

  # 7. 完成安装
  mark_installed "$dir"
  rm -f "$PENDING_FILE"
  echo "[$(timestamp)] 安装完成：$NAME"
}

# ==============================================================================
# 独立命令支持：prepare <stack_name>
# ==============================================================================
if [ "${1:-}" = "prepare" ]; then
  stack_name="${2:-}"
  [ -z "$stack_name" ] && { echo "用法: $0 prepare <stack_name>"; exit 1; }
  
  target_stack="$REPO_ROOT/stacks/$stack_name"
  hook="$target_stack/hooks/pre-install.sh"
  
  if [ -x "$hook" ]; then
    export RUNTIME_DIR="$(runtime_dir_for_stack "$target_stack")"
    export STACK_DIR="$target_stack"
    "$hook"
  else
    echo "未找到该 Stack 的预处理钩子: $hook"
    exit 1
  fi
  exit 0
fi

# ==============================================================================
# 主入口 (Main)
# ==============================================================================
main() {
  need_cmd docker
  need_cmd find

  if [ -f "$PENDING_FILE" ]; then
    echo "[$(timestamp)] 检测到未完成的安装，正在恢复..."
    # shellcheck disable=SC1090
    source "$PENDING_FILE"
    install_stack "$STACK_DIR"
    exit 0
  fi

  declare -a METAS=()
  mapfile -t METAS < <(find "$REPO_ROOT/stacks" -type f -name stack.meta 2>/dev/null | sort)
  
  declare -a MENU_DIRS=()
  declare -a MENU_LINES=()

  for meta in "${METAS[@]}"; do
    dir="$(dirname "$meta")"
    NAME=""; CATEGORY=""; DESCRIPTION=""; REQUIRES_NETWORK=""
    source "$meta"
    [ -z "$NAME" ] && continue
    extra=""
    [ -n "${REQUIRES_NETWORK:-}" ] && extra="needs:${REQUIRES_NETWORK}"
    is_installed "$dir" && extra="$extra 已安装"
    MENU_DIRS+=("$dir")
    MENU_LINES+=("[$CATEGORY] $NAME - $DESCRIPTION ${extra:+($extra)}")
  done

  echo
  for i in "${!MENU_LINES[@]}"; do printf "%3d) %s\n" "$((i+1))" "${MENU_LINES[$i]}"; done
  echo "  0) 退出"
  echo
  read -r -p "请输入编号： " choice
  [ "$choice" = "0" ] && exit 0
  
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#MENU_DIRS[@]}" ]; then
    echo "无效选择"; exit 1
  fi

  install_stack "${MENU_DIRS[$((choice-1))]}"
}

main "$@"