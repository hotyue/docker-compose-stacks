#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# v1.3.5 · Vaultwarden Pre-install Hook (Shell Protection Version)
# ==============================================================================

echo "[Hook] 正在执行 Vaultwarden 数据库治理 (v1.3.5)..."

# 1. 环境加载 (Secure Loading)
TARGET_ENV="${RUNTIME_DIR:-/opt/docker/vaultwarden}/.env"
if [ -f "$TARGET_ENV" ]; then
    set -a
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
        value=$(echo "$value" | sed -e "s/^['\"]//" -e "s/['\"]$//")
        export "$key"="$value"
    done < "$TARGET_ENV"
    set +a
fi

# 2. 数据库容器就绪检查
DB_CONTAINER="${VAULTWARDEN_DB_HOST:-mariadb}"
until [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" == "true" ]; do
    echo "  - 等待数据库就绪..."
    sleep 2
done

# 3. 注入 SQL (🌟 关键：使用 'SQL' 加单引号，防止变量在宿主机侧被 Bash 干扰)
echo "[Hook] 正在同步 Vaultwarden 账号权限..."
docker exec -i "$DB_CONTAINER" mariadb \
  -u "${VAULTWARDEN_DB_ADMIN_USER}" \
  -p"${VAULTWARDEN_DB_ADMIN_PASSWORD}" <<'SQL'

-- 1. 确保数据库存在
CREATE DATABASE IF NOT EXISTS `${VAULTWARDEN_DB_NAME}`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 2. 同步账号与密码
-- 使用当前环境变量中的值
CREATE USER IF NOT EXISTS '${VAULTWARDEN_DB_USER}'@'%' IDENTIFIED BY '${VAULTWARDEN_DB_PASSWORD}';
ALTER USER '${VAULTWARDEN_DB_USER}'@'%' IDENTIFIED BY '${VAULTWARDEN_DB_PASSWORD}';

-- 3. 授权 (包含 REFERENCES 以支持外键)
GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER, REFERENCES
ON `${VAULTWARDEN_DB_NAME}`.* TO '${VAULTWARDEN_DB_USER}'@'%';

-- 4. 强制刷新
FLUSH PRIVILEGES;
SQL

echo "[Hook] 数据库同步完成。"