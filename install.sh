#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Docker Compose Stacks Installer
# ==============================================================================
# 核心安装脚本，负责：
# 1. 依赖环境检测
# 2. Stack 资源同步（物理复制）
# 3. 环境变量 (.env) 交互式生成
# 4. 容器启动与初始化治理
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
# 假设 lifecycle.sh 定义了 TASKS_prepare_traccar 等变量
source "$REPO_ROOT/scripts/lib/lifecycle.sh" 

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
# v1.2.0 特性：Traccar 预处理任务
# ==============================================================================

run_prepare_tasks_traccar() {
  echo "[$(timestamp)] [prepare] traccar: 开始执行预处理任务..."

  local task
  # TASKS_prepare_traccar 应在 lifecycle.sh 中定义
  for task in "${TASKS_prepare_traccar[@]}"; do
    IFS=':' read -r task_id task_path <<<"$task"

    echo "[$(timestamp)] [prepare] 执行任务: $task_id"

    if [ ! -x "$REPO_ROOT/$task_path" ]; then
      echo "[$(timestamp)] [prepare] 错误: 任务脚本不可执行 -> $task_path"
      exit 1
    fi

    # shellcheck disable=SC1090
    "$REPO_ROOT/$task_path" || {
      echo "[$(timestamp)] [prepare] 失败: 任务 $task_id 执行出错"
      exit 1
    }
  done

  echo "[$(timestamp)] [prepare] traccar: 所有预处理任务已完成"
}

# ==============================================================================
# 核心逻辑：资源同步 (Stack Asset Sync)
# ==============================================================================
# v1.2.3 变更：移除对 docker-compose.yml 的排除，改为物理复制
# 原因：防止 /tmp 临时目录被系统清理后，软链接失效导致服务无法管理
# ==============================================================================
sync_stack_assets() {
  local src_dir="$1"
  local runtime_dir="$2"

  if command -v rsync >/dev/null 2>&1; then
    # 使用 rsync 同步 (保留属性)
    rsync -a \
      --exclude 'stack.meta' \
      --exclude '.env.example' \
      --exclude '.git' \
      --exclude '.gitignore' \
      --exclude '.github' \
      --exclude '.DS_Store' \
      --exclude '.env' \
      "$src_dir/" "$runtime_dir/"
  else
    # 降级方案：使用 cp (兼容无 rsync 环境)
    local item
    shopt -s dotglob nullglob
    for item in "$src_dir"/* "$src_dir"/.*; do
      case "$(basename "$item")" in
        # 排除列表
        "."|".."|"stack.meta"|".env.example"|".env"|".git"|".github"|".gitignore"|".DS_Store")
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

  # 2. 同步资源 (物理复制，含 docker-compose.yml)
  sync_stack_assets "$dir" "$runtime_dir"

  # 3. 处理 .env 配置
  ENV_CREATED=false

  # 3.1 如果目标不存在 .env，从 example 复制
  if [ -f "$dir/.env.example" ] && [ ! -f "$runtime_dir/.env" ]; then
    cp "$dir/.env.example" "$runtime_dir/.env"
    ENV_CREATED=true
    echo "[$(timestamp)] 已生成运行目录 .env（来自 .env.example）"
  fi

  # 3.2 校验 .env 必填项
  if [ -f "$dir/.env.example" ] && [ -f "$runtime_dir/.env" ]; then
    required_keys=$(
      grep -Ev '^\s*#|^\s*$' "$dir/.env.example" |
      grep '=' |
      grep -v '=$' |
      cut -d= -f1
    )

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

  # 4. 首次生成配置时的中断保护 (Pending 机制)
  if [ "$ENV_CREATED" = true ]; then
    {
      echo "STACK_DIR=$dir"
      echo "RUNTIME_DIR=$runtime_dir"
    } > "$PENDING_FILE"

    echo "--------------------------------------------------"
    echo "已生成配置文件："
    echo "  $runtime_dir/.env"
    echo
    echo "在继续安装前，你需要手动修改该文件中的配置项。"
    echo
    echo "修改完成后，重新运行 installer 将继续安装。"
    echo "--------------------------------------------------"
    echo "[$(timestamp)] 首次生成 .env，安装已暂停。"
    exit 0
  fi

  # 5. 特定 Stack 的预处理钩子 (Traccar v1.2.0)
  if [ "$(basename "$dir")" = "traccar" ]; then
    echo "[$(timestamp)] 触发 v1.2.0 Traccar 预处理..."
    run_prepare_tasks_traccar
  fi

  # 6. 启动服务与智能清理
  echo "[$(timestamp)] 启动服务中..."
  (
    cd "$runtime_dir"
    
    # ⚠️ v1.2.3 变更：删除软链接命令 (ln -sf)，文件已在 sync_stack_assets 中物理复制
    # ln -sf "$dir/docker-compose.yml" docker-compose.yml  <-- 已移除
    
    $COMPOSE_CMD up -d

    # === 智能清理逻辑 (Smart Cleanup) ===
    # 仅清理成功完成 (Exit 0) 的初始化容器，保留失败容器供调试
    echo "[$(timestamp)] 检查并清理初始化容器..."
    sleep 3 # 等待容器状态更新
    
    # 获取当前 Stack 下所有已停止的容器 ID
    stopped_containers=$($COMPOSE_CMD ps -a --filter "status=exited" -q)
    
    if [ -n "$stopped_containers" ]; then
      for container_id in $stopped_containers; do
        # 检查退出代码
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
# 独立命令支持：prepare
# ==============================================================================
if [ "${1:-}" = "prepare" ]; then
  stack="${2:-}"
  if [ "$stack" != "traccar" ]; then
    echo "[$(timestamp)] prepare 命令目前仅支持: traccar (v1.2.0)"
    exit 1
  fi

  run_prepare_tasks_traccar
  exit 0
fi

# ==============================================================================
# 主入口 (Main)
# ==============================================================================
main() {
  need_cmd docker
  need_cmd find

  # 1. 恢复未完成的安装
  if [ -f "$PENDING_FILE" ]; then
    echo "[$(timestamp)] 检测到未完成的安装，正在恢复..."
    # shellcheck disable=SC1090
    source "$PENDING_FILE"

    if [ -z "${STACK_DIR:-}" ]; then
      echo "[$(timestamp)] ERROR: pending 状态损坏，请手动清理。"
      exit 1
    fi

    install_stack "$STACK_DIR"
    exit 0
  fi

  # 2. 扫描 Stacks
  declare -a METAS=()
  mapfile -t METAS < <(find "$REPO_ROOT/stacks" -type f -name stack.meta 2>/dev/null | sort)
  if [ "${#METAS[@]}" -eq 0 ]; then
    echo "[$(timestamp)] 未找到任何 stack.meta"
    exit 1
  fi

  declare -a MENU_DIRS=()
  declare -a MENU_LINES=()

  local dir NAME CATEGORY DESCRIPTION REQUIRES_NETWORK

  # 3. 构建菜单
  for meta in "${METAS[@]}"; do
    dir="$(dirname "$meta")"
    NAME=""; CATEGORY=""; DESCRIPTION=""; REQUIRES_NETWORK=""

    # shellcheck disable=SC1090
    source "$meta"

    [ -z "$NAME" ] && continue
    [ -z "$CATEGORY" ] && continue
    [ -z "$DESCRIPTION" ] && continue

    local extra=""
    [ -n "${REQUIRES_NETWORK:-}" ] && extra="needs:${REQUIRES_NETWORK}"
    is_installed "$dir" && extra="$extra 已安装"

    MENU_DIRS+=("$dir")
    MENU_LINES+=("[$CATEGORY] $NAME - $DESCRIPTION ${extra:+($extra)}")
  done

  # 4. 显示菜单交互
  echo
  echo "可安装应用栈："
  for i in "${!MENU_LINES[@]}"; do
    printf "%3d) %s\n" "$((i+1))" "${MENU_LINES[$i]}"
  done
  echo "  0) 退出"
  echo

  read -r -p "请输入编号： " choice
  if [ "$choice" = "0" ]; then
    echo "[$(timestamp)] 已退出。"
    exit 0
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#MENU_DIRS[@]}" ]; then
    echo "[$(timestamp)] 无效选择：$choice"
    exit 1
  fi

  local target="${MENU_DIRS[$((choice-1))]}"
  if is_installed "$target"; then
    echo "[$(timestamp)] 该应用已安装，如需重装请先手动清理。"
    exit 0
  fi

  # 5. 执行安装
  install_stack "$target"
}

main "$@"