#!/usr/bin/env bash
set -e

# ==============================================================================
# Nezha Server 数据库初始化与配置引导 (v1.4.1 修复版)
# ==============================================================================

echo "[Init] 正在连接数据库 ${NEZHA_DB_HOST}..."

# 1. 等待数据库就绪
# ------------------------------------------------------------------------------
# 修复：必须带上管理员账号密码，否则数据库会拒绝连接导致无限循环
until mariadb-admin ping -h "${NEZHA_DB_HOST}" -u "${NEZHA_DB_ADMIN_USER}" -p"${NEZHA_DB_ADMIN_PASSWORD}" --silent; do
    echo "  - 数据库暂不可用 (或权限拒绝)，重试中..."
    sleep 2
done



# 2. 数据库初始化 (建库、建人、授权)
# ------------------------------------------------------------------------------
echo "[Init] 正在执行 SQL 初始化..."

mariadb \
  -h "${NEZHA_DB_HOST}" \
  -P "${NEZHA_DB_PORT}" \
  -u "${NEZHA_DB_ADMIN_USER}" \
  -p"${NEZHA_DB_ADMIN_PASSWORD}" <<SQL

-- 创建数据库
CREATE DATABASE IF NOT EXISTS \`${NEZHA_DB_NAME}\`
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

-- 创建用户 (如果存在则忽略)
CREATE USER IF NOT EXISTS '${NEZHA_DB_USER}'@'%'
  IDENTIFIED BY '${NEZHA_DB_PASSWORD}';

-- 强制同步密码 (核心：防止 .env 修改密码后数据库未更新导致 Access Denied)
ALTER USER '${NEZHA_DB_USER}'@'%'
  IDENTIFIED BY '${NEZHA_DB_PASSWORD}';

-- 授权 (Nezha 需要完整的 DDL 权限进行自动迁移)
GRANT ALL PRIVILEGES ON \`${NEZHA_DB_NAME}\`.* TO '${NEZHA_DB_USER}'@'%';

-- 刷新权限
FLUSH PRIVILEGES;

SQL

echo "[Init] 数据库权限已同步。"

# 3. 核心：生成 config.yaml (引导使用 MySQL)
# ------------------------------------------------------------------------------
# 只有生成了这个文件，Nezha 主容器启动时才会连接 MySQL
# 否则它会默认生成 SQLite 数据库，导致配置失效

CONFIG_DIR="/dashboard/data"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

# 确保目录存在 (防止挂载点未自动创建)
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[Init] 未检测到配置文件，正在生成 config.yaml (MySQL模式)..."
  
  # 写入配置
  # 注意：gRPC 端口对于 Agent 连接至关重要
  cat > "$CONFIG_FILE" <<EOF
debug: false
language: zh-CN
site_name: Nezha Monitoring
httpport: ${NEZHA_HTTP_PORT:-8008}
grpcport: ${NEZHA_GRPC_PORT:-5555}
type: mysql
db: "${NEZHA_DB_USER}:${NEZHA_DB_PASSWORD}@tcp(${NEZHA_DB_HOST}:${NEZHA_DB_PORT})/${NEZHA_DB_NAME}?charset=utf8mb4&parseTime=True&loc=Local"
EOF

  # 放宽权限，确保主容器(非root用户)能读写
  chmod 666 "$CONFIG_FILE"
  echo "[Init] 配置文件 config.yaml 生成完毕。"
else
  echo "[Init] 配置文件已存在，跳过生成步骤。"
fi

echo "[Init] 初始化流程结束。"