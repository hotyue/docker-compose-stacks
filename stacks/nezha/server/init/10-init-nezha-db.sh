#!/usr/bin/env bash
set -e

# ==========================================================
# v1.1.9 · Nezha Server 逻辑数据库初始化脚本
# ==========================================================
#
# 职责限定：
# - 创建 Nezha Server 专属逻辑数据库
# - 创建 Nezha Server 专属数据库用户
# - 授权该用户仅访问其数据库
#
# 严格约束：
# - 仅在初始化阶段执行
# - 不参与运行期
# - 不创建或修改平台级数据库结构
# - 不接触其他 Stack 的数据库
#
# 技术约束：
# - 适配 MariaDB 11
# - 使用官方 mariadb 客户端
# - 幂等，可重复执行
# ==========================================================

mariadb \
  -h "${NEZHA_DB_HOST}" \
  -P "${NEZHA_DB_PORT}" \
  -u "${NEZHA_DB_ADMIN_USER}" \
  -p"${NEZHA_DB_ADMIN_PASSWORD}" <<SQL

-- ----------------------------------------------------------
-- 创建 Nezha Server 专属逻辑数据库
-- ----------------------------------------------------------
CREATE DATABASE IF NOT EXISTS \`${NEZHA_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- ----------------------------------------------------------
-- 创建 Nezha Server 专属数据库用户
-- ----------------------------------------------------------
CREATE USER IF NOT EXISTS '${NEZHA_DB_USER}'@'%'
  IDENTIFIED BY '${NEZHA_DB_PASSWORD}';

-- ----------------------------------------------------------
-- 授权最小权限（仅限本逻辑数据库）
-- ----------------------------------------------------------
GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER
ON \`${NEZHA_DB_NAME}\`.* TO '${NEZHA_DB_USER}'@'%';

FLUSH PRIVILEGES;

SQL
