#!/bin/sh
set -e

# v1.1.10 WordPress 逻辑数据库初始化（最终冻结版 / POSIX sh）
#
# 约束：
# - 只能使用 /bin/sh
# - 不能使用 bash 语法
# - 必须在 mariadb:11 镜像中可直接执行

echo "[wp-db-init] Validating required environment variables..."

# 显式校验变量（sh 兼容）
check_var() {
  name="$1"
  eval "value=\${$name}"
  if [ -z "$value" ]; then
    echo "[wp-db-init] FATAL: required env var '$name' is not set or empty." >&2
    exit 1
  fi
}

check_var WP_DB_HOST
check_var WP_DB_PORT
check_var WP_DB_ADMIN_USER
check_var WP_DB_ADMIN_PASSWORD
check_var WP_DB_NAME
check_var WP_DB_USER
check_var WP_DB_PASSWORD

echo "[wp-db-init] Checking database connectivity..."
mariadb \
  -h "$WP_DB_HOST" \
  -P "$WP_DB_PORT" \
  -u "$WP_DB_ADMIN_USER" \
  -p"$WP_DB_ADMIN_PASSWORD" \
  -e "SELECT 1;" >/dev/null

echo "[wp-db-init] Checking admin privileges (GRANT OPTION required)..."

GRANTS_OUTPUT="$(mariadb \
  -h "$WP_DB_HOST" \
  -P "$WP_DB_PORT" \
  -u "$WP_DB_ADMIN_USER" \
  -p"$WP_DB_ADMIN_PASSWORD" \
  -N -e "SHOW GRANTS FOR CURRENT_USER();" || true)"

echo "$GRANTS_OUTPUT" | grep -qi "GRANT OPTION" || {
  cat >&2 <<EOF
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
}

echo "[wp-db-init] Initializing WordPress database and user (idempotent)..."

mariadb \
  -h "$WP_DB_HOST" \
  -P "$WP_DB_PORT" \
  -u "$WP_DB_ADMIN_USER" \
  -p"$WP_DB_ADMIN_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS \`$WP_DB_NAME\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '$WP_DB_USER'@'%'
  IDENTIFIED BY '$WP_DB_PASSWORD';

GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  LOCK TABLES
ON \`$WP_DB_NAME\`.* TO '$WP_DB_USER'@'%';

FLUSH PRIVILEGES;
SQL

echo "[wp-db-init] Initialization completed successfully."
