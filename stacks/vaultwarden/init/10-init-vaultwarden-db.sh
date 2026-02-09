#!/usr/bin/env bash
set -e

# v1.1.12 Vaultwarden 逻辑数据库初始化
# 仅负责：
# - 创建 Vaultwarden 专属数据库
# - 创建 Vaultwarden 专属用户
# - 授权该用户仅访问其数据库（最小权限）
#
# 适配 MariaDB 11
# 使用 mariadb 客户端
# 幂等，可重复执行

mariadb \
  -h "${VAULTWARDEN_DB_HOST}" \
  -P "${VAULTWARDEN_DB_PORT}" \
  -u "${VAULTWARDEN_DB_ADMIN_USER}" \
  -p"${VAULTWARDEN_DB_ADMIN_PASSWORD}" <<SQL

CREATE DATABASE IF NOT EXISTS \`${VAULTWARDEN_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${VAULTWARDEN_DB_USER}'@'%'
  IDENTIFIED BY '${VAULTWARDEN_DB_PASSWORD}';

-- 权限集合参考本仓库既有 Matomo 最小权限风格
-- Vaultwarden 使用 MySQL/MariaDB 时需要常规 DDL/DML 权限以完成迁移与运行
GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER
ON \`${VAULTWARDEN_DB_NAME}\`.* TO '${VAULTWARDEN_DB_USER}'@'%';

# FLUSH PRIVILEGES;

SQL