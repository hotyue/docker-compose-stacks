#!/usr/bin/env bash
set -euo pipefail

# =========================
# Installer Global Settings
# =========================
export TZ=UTC
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED_FILE="$REPO_ROOT/.installed"

# =========================
# Runtime Layout Settings
# =========================
RUNTIME_ROOT="/opt/docker"

# =========================
# Runtime Capability Layer
# =========================
# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/lib/runtime.sh"
detect_compose

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[$(timestamp)] 缺少命令：$1"
    exit 1
  }
}

# =========================
# Runtime Helpers
# =========================
runtime_dir_for_stack() {
  local stack_dir="$1"
  local rel
  rel="${stack_dir#"$REPO_ROOT/stacks/"}"
  echo "$RUNTIME_ROOT/$rel"
}

prepare_runtime_dir() {
  local dir="$1"

  if [ ! -d "$dir" ]; then
    echo "[$(timestamp)] 创建运行目录：$dir"
    mkdir -p "$dir"
  fi

  # 权限规则受冻结规范约束：
  # docs/INSTALLER_RUNTIME.md
  # Installer 仅保证运行目录对容器可写，不假设 UID/GID，禁止 chown
  chmod 775 "$dir"
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

# =========================
# Stack Asset Sync (v1.1.7)
# =========================
sync_stack_assets() {
  local src_dir="$1"
  local runtime_dir="$2"

  # 仅在首次安装时进行“完整资产投放”
  # 目标：保证 Stack 私有脚本目录（如 init/）等资产必然落地
  #
  # 注意：
  # - 不复制 stack.meta（运行目录无需该文件）
  # - 不复制 .env.example（由统一 .env handling 接管）
  # - 不复制 .git* 等无关项
  # - 不覆盖运行目录已存在的 .env（防止用户配置丢失）
  #
  # 采用 rsync（若不存在则回退到 cp -a 的保守实现）
  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude 'stack.meta' \
      --exclude '.env.example' \
      --exclude '.git' \
      --exclude '.gitignore' \
      --exclude '.github' \
      --exclude '.DS_Store' \
      --exclude 'docker-compose.yml' \
      --exclude '.env' \
      "$src_dir/" "$runtime_dir/"
  else
    # 无 rsync 时：用 cp -a 逐项复制（排除项手工处理）
    # 该实现不追求“增量同步”，只保证首次安装资产落地
    local item
    shopt -s dotglob nullglob
    for item in "$src_dir"/* "$src_dir"/.*; do
      case "$(basename "$item")" in
        "."|".."|"stack.meta"|".env.example"|".env"|".git"|".github"|".gitignore"|".DS_Store"|"docker-compose.yml")
          continue
          ;;
      esac
      # 只在目标不存在时复制，避免覆盖用户可能修改过的运行时文件
      if [ ! -e "$runtime_dir/$(basename "$item")" ]; then
        cp -a "$item" "$runtime_dir/" 2>/dev/null || true
      fi
    done
    shopt -u dotglob nullglob
  fi
}

install_stack() {
  local dir="$1"

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

  # 准备运行目录
  prepare_runtime_dir "$runtime_dir"

  # 网络确保（若声明）
  ensure_network "${REQUIRES_NETWORK:-}"

  #############################################
  # v1.1.7 - stack asset sync (BEGIN)
  #############################################
  # 首次安装时，将 Stack 目录的私有资产完整投放到运行目录，
  # 以保证 init/ 等子目录不会丢失。
  #
  # 注意：不会覆盖运行目录既有 .env
  sync_stack_assets "$dir" "$runtime_dir"
  #############################################
  # v1.1.7 - stack asset sync (END)
  #############################################

  #############################################
  # v1.0.3 - unified .env handling (BEGIN)
  #############################################

  ENV_CREATED=false

  if [ -f "$dir/.env.example" ] && [ ! -f "$runtime_dir/.env" ]; then
    cp "$dir/.env.example" "$runtime_dir/.env"
    ENV_CREATED=true
    echo "[$(timestamp)] 已生成运行目录 .env（来自 .env.example）"
  fi

  # validate required keys from .env.example
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

  # notify user and hard-stop on first .env creation
  if [ "$ENV_CREATED" = true ]; then
    echo "--------------------------------------------------"
    echo "已生成配置文件："
    echo "  $runtime_dir/.env"
    echo
    echo "在继续安装前，你需要手动修改该文件中的配置项。"
    echo
    echo "可使用以下命令进行编辑："
    echo "  vi $runtime_dir/.env"
    echo "  # 或"
    echo "  nano $runtime_dir/.env"
    echo
    echo "修改完成后，请重新运行 install.sh 以继续安装。"
    echo "--------------------------------------------------"
    echo "[$(timestamp)] 首次生成 .env，安装已暂停。"
    exit 0
  fi

  #############################################
  # v1.0.3 - unified .env handling (END)
  #############################################

  echo "[$(timestamp)] 启动服务中..."
  (
    cd "$runtime_dir"

    # v1.1.6：复制数据库初始化脚本（仅首次安装）
    # docker-entrypoint-initdb.d 仅用于初始化阶段，是否执行由官方 entrypoint 判定
    if [ -d "$dir/docker-entrypoint-initdb.d" ] && \
       [ ! -d "$runtime_dir/docker-entrypoint-initdb.d" ]; then
      mkdir -p "$runtime_dir/docker-entrypoint-initdb.d"
      cp -a "$dir/docker-entrypoint-initdb.d/." \
            "$runtime_dir/docker-entrypoint-initdb.d/" \
            2>/dev/null || true
    fi

    ln -sf "$dir/docker-compose.yml" docker-compose.yml
    $COMPOSE_CMD up -d
  )

  mark_installed "$dir"
  echo "[$(timestamp)] 安装完成：$NAME"
}

main() {
  need_cmd docker
  need_cmd find

  declare -a METAS=()
  mapfile -t METAS < <(find "$REPO_ROOT/stacks" -type f -name stack.meta 2>/dev/null | sort)
  if [ "${#METAS[@]}" -eq 0 ]; then
    echo "[$(timestamp)] 未找到任何 stack.meta"
    exit 1
  fi

  # 注意：不要使用 LINES 作为变量名（Bash 特殊变量）
  declare -a MENU_DIRS=()
  declare -a MENU_LINES=()

  local dir NAME CATEGORY DESCRIPTION REQUIRES_NETWORK

  for meta in "${METAS[@]}"; do
    dir="$(dirname "$meta")"
    NAME=""; CATEGORY=""; DESCRIPTION=""; REQUIRES_NETWORK=""

    # shellcheck disable=SC1090
    source "$meta"

    # 元数据合法性校验
    [ -z "$NAME" ] && continue
    [ -z "$CATEGORY" ] && continue
    [ -z "$DESCRIPTION" ] && continue

    local extra=""
    [ -n "${REQUIRES_NETWORK:-}" ] && extra="needs:${REQUIRES_NETWORK}"
    is_installed "$dir" && extra="$extra 已安装"

    MENU_DIRS+=("$dir")
    MENU_LINES+=("[$CATEGORY] $NAME - $DESCRIPTION ${extra:+($extra)}")
  done

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

  install_stack "$target"
}

main "$@"
