#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# v1.3.2 · Vaultwarden Pre-install Hook (Robust Auth Version)
# ==============================================================================
# 变更说明：
# 1. 采用安全加载模式，完美处理包含 $9 等特殊符号的强密码。
# 2. 增加 ALTER USER 逻辑，确保数据库内用户密码与当前 .env 强制同步。
# 3. 增加 FLUSH PRIVILEGES，彻底解决 Vaultwarden 启动时的 Access Denied 报错。
# ==============================================================================

echo "[Hook] 正在执行 Vaultwarden 数据库治理 (v1.3.2)..."

# ------------------------------------------------------------------------------
# 1. 安全环境加载 (Environment Loading)
# ------------------------------------------------------------------------------
TARGET_ENV="${RUNTIME_DIR:-/opt/docker/vaultwarden}/.env"

if [ -f "$TARGET_ENV" ]; then
    echo "[Hook] 加载运行时配置: $TARGET_ENV"
    set -a
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # 忽略注释和空行
        [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
        # 去除首尾引号并导出
        value=$(echo "$value" | sed -e "s/^['\"]//" -e "s/['\"]$//")
        export "$key"="$value"
    done < "$TARGET_ENV"
    set +a
else
    echo "[Hook] 错误: 找不到配置文件 $TARGET_ENV，无法继续初始化。"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. 数据库容器状态检查 (Service Readiness)
# ------------------------------------------------------------------------------
DB_CONTAINER="${VAULTWARDEN_DB_HOST:-mariadb}"

echo "[Hook] 检查数据库容器 [$DB_CONTAINER]..."
until [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" == "true" ]; do
    echo "  - 数据库尚未就绪，等待中..."
    sleep 2
done

# ------------------------------------------------------------------------------
# 3. 注入初始化 SQL (Database Initialization)
# ------------------------------------------------------------------------------
echo "[Hook] 正在同步 Vaultwarden 数据库账号与权限..."

docker exec -i "$DB_CONTAINER" mariadb \
  -u "${VAULTWARDEN_DB_ADMIN_USER}" \
  -p"${VAULTWARDEN_DB_ADMIN_PASSWORD}" <<SQL

-- 1. 确保逻辑数据库存在
CREATE DATABASE IF NOT EXISTS \`${VAULTWARDEN_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 2. 强制同步用户与密码
-- 先尝试创建，若已存在则通过 ALTER 强制更新密码，确保与 .env 一致
CREATE USER IF NOT EXISTS '${VAULTWARDEN_DB_USER}'@'%'
  IDENTIFIED BY '${VAULTWARDEN_DB_PASSWORD}';

ALTER USER '${VAULTWARDEN_DB_USER}'@'%'
  IDENTIFIED BY '${VAULTWARDEN_DB_PASSWORD}';

-- 3. 授权 (包含 REFERENCES 以支持 Diesel ORM 外键迁移)
GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER, REFERENCES
ON \`${VAULTWARDEN_DB_NAME}\`.* TO '${VAULTWARDEN_DB_USER}'@'%';

-- 4. 强制刷新权限表
FLUSH PRIVILEGES;
SQL

echo "[Hook] Vaultwarden 数据库初始化与权限同步任务已完成。"