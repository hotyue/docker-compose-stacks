#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# v1.2.6 · Traccar Pre-install Hook (Standardized & Security Fix)
# ==============================================================================
# 变更记录：
# 1. 修复：改用 read 逐行加载环境变量，解决密码中包含 $ 等特殊字符导致的崩溃。
# 2. 架构：维持 Docker Exec 模式，确保 proxy 网络架构下的数据库穿透。
# 3. 健壮性：增加对 .env 文件中带引号/不带引号内容的通用处理。
# ==============================================================================

echo "[Hook] 正在执行 Traccar 预安装钩子..."

# ------------------------------------------------------------------------------
# 1. 安全环境加载 (Secure Environment Loading)
# ------------------------------------------------------------------------------
TARGET_ENV="${RUNTIME_DIR:-/opt/docker/traccar}/.env"

if [ -f "$TARGET_ENV" ]; then
    echo "[Hook] 加载运行时配置: $TARGET_ENV"
    
    # 🌟 核心修复：不使用 source，防止 Bash 解析 $9, $1 等变量
    # 通过 read 循环读取，并使用 eval 导出，确保特殊符号被视为纯字符串
    set -a
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # 跳过注释行和空行
        [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
        
        # 去除 value 可能存在的首尾引号 (单引号或双引号)
        value=$(echo "$value" | sed -e "s/^['\"]//" -e "s/['\"]$//")
        
        # 导出变量
        export "$key"="$value"
    done < "$TARGET_ENV"
    set +a
else
    echo "[Hook] 错误: 找不到配置文件 $TARGET_ENV，无法继续初始化。"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. 容器状态检查 (Wait for MariaDB Container)
# ------------------------------------------------------------------------------
# 这里的 DB_CONTAINER 将准确获取刚才导出的 MARIADB_HOST
DB_CONTAINER="${MARIADB_HOST:-mariadb}"

echo "[Hook] 正在检查数据库容器 [$DB_CONTAINER] 的可用性..."

# 确保目标容器正在运行
until [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" == "true" ]; do
    echo "  - 数据库容器 [$DB_CONTAINER] 尚未就绪，等待中..."
    sleep 2
done

# ------------------------------------------------------------------------------
# 3. 数据库初始化 (Execute via Docker Exec)
# ------------------------------------------------------------------------------
# 使用 docker exec 注入 SQL，完全绕过宿主机与容器间的网络层限制
echo "[Hook] 正在通过容器内部通道初始化 Traccar 数据库..."

docker exec -i "$DB_CONTAINER" mariadb \
  -u "${DB_ADMIN_USER}" \
  -p"${DB_ADMIN_PASSWORD}" <<SQL

-- 1. 创建 Traccar 专属逻辑数据库
CREATE DATABASE IF NOT EXISTS \`${TRACCAR_DB_NAME}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 2. 创建 Traccar 专属数据库用户
CREATE USER IF NOT EXISTS '${TRACCAR_DB_USER}'@'%'
  IDENTIFIED BY '${TRACCAR_DB_PASSWORD}';

-- 3. 授权 (适配 MariaDB 11 最小权限集)
GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW, SHOW VIEW,
  EVENT, TRIGGER
ON \`${TRACCAR_DB_NAME}\`.*
TO '${TRACCAR_DB_USER}'@'%';

-- FLUSH PRIVILEGES;
SQL

echo "[Hook] Traccar 数据库初始化任务已成功完成。"