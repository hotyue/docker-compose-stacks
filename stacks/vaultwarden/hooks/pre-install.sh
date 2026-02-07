#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# v1.3.3 · Vaultwarden Pre-install Hook (Strict Auth Sync)
# ==============================================================================

echo "[Hook] 正在执行 Vaultwarden 数据库治理 (v1.3.3)..."

# 1. 安全环境加载
TARGET_ENV="${RUNTIME_DIR:-/opt/docker/vaultwarden}/.env"
if [ -f "$TARGET_ENV" ]; then
    set -a
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
        value=$(echo "$value" | sed -e "s/^['\"]//" -e "s/['\"]$//")
        export "$key"="$value"
    done < "$TARGET_ENV"
    set +a
else
    echo "[Hook] 错误: 找不到配置文件 $TARGET_ENV"; exit 1
fi

# 2. 数据库容器就绪检查
DB_CONTAINER="${VAULTWARDEN_DB_HOST:-mariadb}"
until [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" == "true" ]; do
    sleep 2
done

# 3. 注入 SQL (核心：CREATE + ALTER + FLUSH)
echo "[Hook] 正在同步 Vaultwarden 账号权限..."
docker exec -i "$DB_CONTAINER" mariadb \
  -u "${VAULTWARDEN_DB_ADMIN_USER}" \
  -p"${VAULTWARDEN_DB_ADMIN_PASSWORD}" <<SQL
-- 创建逻辑库
CREATE DATABASE IF NOT EXISTS \`${VAULTWARDEN_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 强制同步用户密码
CREATE USER IF NOT EXISTS '${VAULTWARDEN_DB_USER}'@'%' IDENTIFIED BY '${VAULTWARDEN_DB_PASSWORD}';
ALTER USER '${VAULTWARDEN_DB_USER}'@'%' IDENTIFIED BY '${VAULTWARDEN_DB_PASSWORD}';

-- 授权 (显式包含 REFERENCES)
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, EVENT, TRIGGER, REFERENCES ON \`${VAULTWARDEN_DB_NAME}\`.* TO '${VAULTWARDEN_DB_USER}'@'%';

-- 刷新生效
FLUSH PRIVILEGES;
SQL

echo "[Hook] Vaultwarden 数据库初始化成功。"