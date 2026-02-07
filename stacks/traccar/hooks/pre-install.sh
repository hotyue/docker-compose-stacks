#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# v1.2.5 · Traccar Pre-install Hook (Architecture Optimized)
# ==============================================================================
# 职责：
# 1. 加载运行时 .env 环境变量
# 2. 通过 docker exec 直接进入数据库容器内部进行初始化
# 3. 适配项目全局 proxy 架构，消除宿主机与容器间的网络隔离问题
# ==============================================================================

echo "[Hook] 正在执行 Traccar 预安装钩子 (Docker Exec 模式)..."

# ------------------------------------------------------------------------------
# 1. 环境加载 (Environment Loading)
# ------------------------------------------------------------------------------
TARGET_ENV="${RUNTIME_DIR:-/opt/docker/traccar}/.env"

if [ -f "$TARGET_ENV" ]; then
    echo "[Hook] 加载运行时配置: $TARGET_ENV"
    set -a
    # shellcheck disable=SC1090
    source "$TARGET_ENV"
    set +a
else
    echo "[Hook] 错误: 找不到配置文件 $TARGET_ENV，无法继续初始化。"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. 容器状态检查 (Wait for MariaDB Container)
# ------------------------------------------------------------------------------
# 根据 .env 中的 MARIADB_HOST 确定容器名
DB_CONTAINER="${MARIADB_HOST:-mariadb}"

echo "[Hook] 正在检查数据库容器 [$DB_CONTAINER] 的可用性..."

# 确保目标容器正在运行
until [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" == "true" ]; do
    echo "  - 数据库容器 [$DB_CONTAINER] 尚未就绪，等待中..."
    sleep 2
done

# ------------------------------------------------------------------------------
# 3. 数据库初始化 (Execute via Docker Exec)
# ------------------------------------------------------------------------------
# 🌟 修复说明：不再通过 127.0.0.1 连接，直接注入 SQL 到容器内部执行
# 这种方式不仅消除了网络不通的风险，还不需要宿主机安装 mariadb-client
echo "[Hook] 正在通过容器内部通道初始化 Traccar 数据库..."

docker exec -i "$DB_CONTAINER" mariadb \
  -u "${DB_ADMIN_USER}" \
  -p"${DB_ADMIN_PASSWORD}" <<SQL

-- 1. 创建 Traccar 专属逻辑数据库
CREATE DATABASE IF NOT EXISTS \`${TRACCAR_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 2. 创建 Traccar 专属数据库用户
CREATE USER IF NOT EXISTS '${TRACCAR_DB_USER}'@'%'
  IDENTIFIED BY '${TRACCAR_DB_PASSWORD}';

-- 3. 授权 (适配 MariaDB 11 最小权限集)
GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER
ON \`${TRACCAR_DB_NAME}\`.*
TO '${TRACCAR_DB_USER}'@'%';

-- FLUSH PRIVILEGES;
SQL

echo "[Hook] Traccar 数据库初始化任务已成功完成。"