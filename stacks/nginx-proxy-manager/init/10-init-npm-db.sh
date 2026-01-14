#!/usr/bin/env bash
set -e

# v1.1.8 Nginx Proxy Manager 逻辑数据库初始化
# 仅负责：
# - 创建 Nginx Proxy Manager 专属数据库
# - 创建 Nginx Proxy Manager 专属用户
# - 授权该用户仅访问其数据库
#
# 适配 MariaDB 11
# 使用 mariadb 客户端
# 幂等，可重复执行

mariadb \
  -h "${NPM_DB_HOST}" \
  -P "${NPM_DB_PORT}" \
  -u "${NPM_DB_ADMIN_USER}" \
  -p"${NPM_DB_ADMIN_PASSWORD}" <<SQL

CREATE DATABASE IF NOT EXISTS \`${NPM_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${NPM_DB_USER}'@'%'
  IDENTIFIED BY '${NPM_DB_PASSWORD}';

GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER
ON \`${NPM_DB_NAME}\`.* TO '${NPM_DB_USER}'@'%';

SQL
