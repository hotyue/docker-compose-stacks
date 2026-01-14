#!/usr/bin/env sh
set -eu

# v1.1.10 WordPress 逻辑数据库初始化（对齐 db_admin 权限集）
# 幂等，可重复执行
#
# 仅负责：
# - 创建 WordPress 专属数据库
# - 创建 WordPress 专属用户
# - 授权该用户访问其数据库（不包含 LOCK TABLES / ALL PRIVILEGES）

mariadb \
  -h "${WP_DB_HOST}" \
  -P "${WP_DB_PORT}" \
  -u "${WP_DB_ADMIN_USER}" \
  -p"${WP_DB_ADMIN_PASSWORD}" <<SQL

CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'%'
  IDENTIFIED BY '${WP_DB_PASSWORD}';

GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES
ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';

FLUSH PRIVILEGES;
SQL
