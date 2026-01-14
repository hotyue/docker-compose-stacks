#!/usr/bin/env bash
set -euo pipefail

# v1.1.10 WordPress 逻辑数据库初始化（最终版）
#
# 职责（严格）：
# - 创建 WordPress 专属逻辑数据库
# - 创建 WordPress 专属数据库用户
# - 授权该用户仅访问其数据库
#
# 治理约束：
# - 仅使用外置 MariaDB / MySQL
# - 不修改 MariaDB Stack
# - 初始化账号必须具备 GRANT OPTION
#
# 关键改进：
# - 初始化前校验管理账号权限（GRANT OPTION）
# - 校验失败立即退出，不产生“半初始化”脏状态
# - 校验通过后再执行全部 SQL（幂等）

# ------------------------------
# 基础连接参数
# ------------------------------
DB_CONN_ARGS=(
  -h "${WP_DB_HOST}"
  -P "${WP_DB_PORT}"
  -u "${WP_DB_ADMIN_USER}"
  -p"${WP_DB_ADMIN_PASSWORD}"
)

echo "[wp-db-init] Checking database connectivity..."
mariadb "${DB_CONN_ARGS[@]}" -e "SELECT 1;" >/dev/null

# ------------------------------
# 权限前置校验（关键）
# ------------------------------
echo "[wp-db-init] Checking admin privileges (GRANT OPTION required)..."

GRANTS_OUTPUT="$(mariadb "${DB_CONN_ARGS[@]}" -N -e "SHOW GRANTS FOR CURRENT_USER();" || true)"

if ! grep -qiE 'WITH GRANT OPTION|ALL PRIVILEGES ON \*\.\*|GRANT OPTION' <<<"$GRANTS_OUTPUT"; then
  cat >&2 <<'EOF'
[wp-db-init] FATAL: Database admin account lacks GRANT OPTION.

This WordPress stack requires an initialization admin account that can:
- CREATE DATABASE
- CREATE USER
- GRANT privileges on the target database

Current admin account is insufficient and initialization is aborted
to prevent a half-initialized (dirty) state.

How to fix:
- Update WP_DB_ADMIN_USER / WP_DB_ADMIN_PASSWORD in .env
  to a real database administrator (e.g. root or equivalent),
  then rerun: docker compose up -d
EOF
  exit 1
fi

# ------------------------------
# 执行初始化（原子化、幂等）
# ------------------------------
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
