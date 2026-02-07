#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# v1.3.0 · Vaultwarden Pre-install Hook
# ==============================================================================

echo "[Hook] 正在执行 Vaultwarden 数据库治理..."

# 1. 安全环境加载 (防止密码特殊字符导致解析崩溃)
TARGET_ENV="${RUNTIME_DIR:-/opt/docker/vaultwarden}/.env"

if [ -f "$TARGET_ENV" ]; then
    echo "[Hook] 加载运行时配置: $TARGET_ENV"
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

# 2. 数据库容器名对齐
DB_CONTAINER="${VAULTWARDEN_DB_HOST:-mariadb}"

echo "[Hook] 检查数据库容器 [$DB_CONTAINER]..."
until [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" == "true" ]; do
    echo "  - 等待数据库就绪..."
    sleep 2
done

# 3. 执行初始化 (使用 Docker Exec)
echo "[Hook] 注入初始化 SQL 到 [$DB_CONTAINER]..."
docker exec -i "$DB_CONTAINER" mariadb \
  -u "${VAULTWARDEN_DB_ADMIN_USER}" \
  -p"${VAULTWARDEN_DB_ADMIN_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${VAULTWARDEN_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${VAULTWARDEN_DB_USER}'@'%'
  IDENTIFIED BY '${VAULTWARDEN_DB_PASSWORD}';

-- 权限集合：包含 REFERENCES 以支持 Diesel ORM 外键迁移
GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER, REFERENCES
ON \`${VAULTWARDEN_DB_NAME}\`.* TO '${VAULTWARDEN_DB_USER}'@'%';
SQL

echo "[Hook] Vaultwarden 数据库初始化任务完成。"