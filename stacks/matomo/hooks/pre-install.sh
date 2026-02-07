#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# v1.3.0 · Matomo Pre-install Hook (Secure Loading & Exec Mode)
# ==============================================================================

echo "[Hook] 正在执行 Matomo 数据库预处理..."

# 1. 安全环境加载 (防止密码特殊字符 $ 引起崩溃)
TARGET_ENV="${RUNTIME_DIR:-/opt/docker/matomo}/.env"

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
DB_CONTAINER="${MATOMO_DB_HOST:-mariadb}"

echo "[Hook] 检查数据库容器 [$DB_CONTAINER]..."
until [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" == "true" ]; do
    echo "  - 等待数据库就绪..."
    sleep 2
done

# 3. 执行初始化 (使用 Docker Exec)
echo "[Hook] 注入初始化 SQL 到 [$DB_CONTAINER]..."
docker exec -i "$DB_CONTAINER" mariadb \
  -u "${MATOMO_DB_ADMIN_USER}" \
  -p"${MATOMO_DB_ADMIN_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${MATOMO_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MATOMO_DB_USER}'@'%'
  IDENTIFIED BY '${MATOMO_DB_PASSWORD}';

GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER
ON \`${MATOMO_DB_NAME}\`.* TO '${MATOMO_DB_USER}'@'%';
SQL

echo "[Hook] Matomo 数据库初始化任务完成。"