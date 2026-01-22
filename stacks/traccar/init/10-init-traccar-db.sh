#!/usr/bin/env bash
set -euo pipefail

# v1.1.13 Traccar 逻辑数据库初始化
# 仅负责：
# - 创建 Traccar 专属数据库
# - 创建 Traccar 专属数据库用户
# - 授权该用户仅访问其数据库
#
# 适配 MariaDB 11
# 使用 mariadb 客户端
# 幂等，可重复执行
#
# ⚠️ 注意：
# - 使用平台级 DB_ADMIN_USER，仅用于初始化阶段
# - 运行期 Traccar 仅使用 TRACCAR_DB_USER

echo "Waiting for MariaDB to be ready..."

until mariadb \
  -h "${MARIADB_HOST}" \
  -P "${MARIADB_PORT}" \
  -u "${DB_ADMIN_USER}" \
  -p"${DB_ADMIN_PASSWORD}" \
  -e "SELECT 1" >/dev/null 2>&1; do
  sleep 2
done

echo "Initializing Traccar database and user..."

mariadb \
  -h "${MARIADB_HOST}" \
  -P "${MARIADB_PORT}" \
  -u "${DB_ADMIN_USER}" \
  -p"${DB_ADMIN_PASSWORD}" <<SQL

CREATE DATABASE IF NOT EXISTS \`${TRACCAR_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${TRACCAR_DB_USER}'@'%'
  IDENTIFIED BY '${TRACCAR_DB_PASSWORD}';

GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER
ON \`${TRACCAR_DB_NAME}\`.*
TO '${TRACCAR_DB_USER}'@'%';

#FLUSH PRIVILEGES;
SQL

echo "Traccar database initialization completed."
