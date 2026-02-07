#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# v1.2.0 · Traccar Pre-install Hook (Standardized)
# ==============================================================================
# 职责：
# 1. 自动加载运行目录下的 .env 环境变量
# 2. 执行 Traccar 专属逻辑数据库与用户的初始化
# ==============================================================================

echo "[Hook] 正在执行 Traccar 预安装钩子..."

# ------------------------------------------------------------------------------
# 1. 环境加载 (Environment Loading)
# ------------------------------------------------------------------------------
# 优先使用 Installer 传递的 RUNTIME_DIR，否则回退到标准运行路径
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
# 2. 数据库等待 (Wait for MariaDB)
# ------------------------------------------------------------------------------
echo "Waiting for MariaDB to be ready at ${MARIADB_HOST}:${MARIADB_PORT}..."

until mariadb \
  -h "${MARIADB_HOST}" \
  -P "${MARIADB_PORT}" \
  -u "${DB_ADMIN_USER}" \
  -p"${DB_ADMIN_PASSWORD}" \
  -e "SELECT 1" >/dev/null 2>&1; do
  echo "  - MariaDB is not reachable, retrying in 2s..."
  sleep 2
done

# ------------------------------------------------------------------------------
# 3. 数据库初始化 (Database Initialization)
# ------------------------------------------------------------------------------
echo "Initializing Traccar database and user..."

mariadb \
  -h "${MARIADB_HOST}" \
  -P "${MARIADB_PORT}" \
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