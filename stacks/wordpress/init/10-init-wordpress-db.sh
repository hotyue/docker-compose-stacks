#!/usr/bin/env bash
set -e

# v1.1.10 WordPress 逻辑数据库初始化（最终冻结版）
#
# 设计原则：
# - 初始化脚本必须可在 bootstrap / installer 环境中稳定运行
# - 不使用 set -u，避免因环境变量加载时序导致非预期退出
# - 关键变量显式校验
# - 权限不足时明确失败，不产生半初始化状态

# ------------------------------
# 必要变量校验
# ------------------------------
required_vars=(
  WP_DB_HOST
  WP_DB_PORT
  WP_DB_ADMIN_USER
  WP_DB_ADMIN_PASSWORD
  WP_DB_NAME
  WP_DB_USER
  WP_DB_PASSWORD
)

for v in "${required_vars[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "[wp-db-init] FATAL: required env var '$v' is not set or empty." >&2
    exit 1
  fi
done

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
