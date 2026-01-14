#!/usr/bin/env bash
set -euo pipefail

# v1.1.10 WordPress 逻辑数据库初始化（最终稳定版）
#
# 设计目标：
# - 初始化前校验管理账号是否具备授权能力
# - 权限不足 → 明确失败并退出（exit 1）
# - 权限满足 → 原子化完成初始化
# - 绝不留下“半初始化”状态

DB_CONN_ARGS=(
  -h "${WP_DB_HOST}"
  -P "${WP_DB_PORT}"
  -u "${WP_DB_ADMIN_USER}"
  -p"${WP_DB_ADMIN_PASSWORD}"
)

echo "[wp-db-init] Checking database connectivity..."
mariadb "${DB_CONN_ARGS[@]}" -e "SELECT 1;" >/dev/null

echo "[wp-db-init] Checking admin privileges (GRANT OPTION required)..."

GRANTS_OUTPUT="$(mariadb "${DB_CONN_ARGS[@]}" -N -e "SHOW GRANTS FOR CURRENT_USER();" || true)"

HAS_GRANT_OPTION=0
if echo "$GRANTS_OUTPUT" | grep -qiE 'WITH GRANT OPTION|ALL PRIVILEGES ON \*\.\*|GRANT OPTION'; then
  HAS_GRANT_OPTION=1
fi

if [ "$HAS_GRANT_OPTION" -ne 1 ]; then
  cat >&2 <<'EOF'
[wp-db-init] FATAL: Database admin account lacks GRANT OPTION.

This WordPress stack requires an initialization admin account that can:
- CREATE DATABASE
- CREATE USER
- GRANT privileges on the target database

Fix:
- Update WP_DB_ADMIN_USER / WP_DB_ADMIN_PASSWORD in .env
  to a real database administrator (e.g. root or equivalent),
  then rerun: docker compose up -d
EOF
  exit 1
fi

echo "[wp-db-init] Initializing WordPress database and user (idempotent)..."

mariadb "${DB_CONN_ARGS[@]}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'%'
  IDENTIFIED BY '${WP_DB_PASSWORD}';

GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  LOCK TABLES
ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';

FLUSH PRIVILEGES;
SQL

echo "[wp-db-init] Initialization completed successfully."
