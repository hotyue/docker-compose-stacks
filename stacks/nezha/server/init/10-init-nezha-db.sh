#!/usr/bin/env bash
set -e

# ==============================================================================
# v1.2.3 · Nezha Server 数据库治理与配置引导脚本
# ==============================================================================
#
# 本脚本包含两个关键阶段：
# 1. 数据库初始化 (Database Init):
#    连接远程 MariaDB，创建专属库和用户。
#
# 2. 配置文件生成 (Config Bootstrap):
#    检测并生成 config.yaml，强制指定 type: mysql。
#    防止 Nezha 因缺省配置而自动降级回 SQLite (导致数据不持久化到 MariaDB)。
#
# ------------------------------------------------------------------------------
# 运行环境约束：
# - 必须挂载 /dashboard/data 目录以写入配置文件
# - 必须提供完整的数据库环境变量
# ==============================================================================

echo "[Nezha-Init] 开始执行初始化流程..."

# ------------------------------------------------------------------------------
# 阶段一：数据库初始化
# ------------------------------------------------------------------------------
echo "[Nezha-Init] 1/2 正在初始化 MariaDB..."

mariadb \
  -h "${NEZHA_DB_HOST}" \
  -P "${NEZHA_DB_PORT}" \
  -u "${NEZHA_DB_ADMIN_USER}" \
  -p"${NEZHA_DB_ADMIN_PASSWORD}" <<SQL

-- 1. 创建 Nezha Server 专属逻辑数据库
CREATE DATABASE IF NOT EXISTS \`${NEZHA_DB_NAME}\`
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

-- 2. 创建 Nezha Server 专属数据库用户
CREATE USER IF NOT EXISTS '${NEZHA_DB_USER}'@'%'
  IDENTIFIED BY '${NEZHA_DB_PASSWORD}';

-- 3. 授权 (使用 ALL PRIVILEGES 确保主程序可执行 Auto Migration 建表)
GRANT ALL PRIVILEGES ON \`${NEZHA_DB_NAME}\`.* TO '${NEZHA_DB_USER}'@'%';

SQL

echo "[Nezha-Init] 数据库 '${NEZHA_DB_NAME}' 初始化完成。"

# ------------------------------------------------------------------------------
# 阶段二：配置文件引导 (防止 SQLite 回退)
# ------------------------------------------------------------------------------
CONFIG_FILE="/dashboard/data/config.yaml"

echo "[Nezha-Init] 2/2 检查配置文件..."

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[Nezha-Init] 未检测到配置文件，正在生成 MySQL 模式配置..."
  
  # 强制写入 MySQL 配置
  # 这里的 httpport 默认 8008，如需更改请在 .env 设置 NEZHA_HTTP_PORT
  cat > "$CONFIG_FILE" <<EOF
debug: false
httpport: ${NEZHA_HTTP_PORT:-8008}
language: zh-CN
site_name: Nezha Monitoring
type: mysql
db: "${NEZHA_DB_USER}:${NEZHA_DB_PASSWORD}@tcp(${NEZHA_DB_HOST}:${NEZHA_DB_PORT})/${NEZHA_DB_NAME}?charset=utf8mb4&parseTime=True&loc=Local"
EOF

  # 赋予宽容权限，确保 Nezha 主进程 (非 root 用户) 可以读取和修改此文件
  chmod 666 "$CONFIG_FILE"
  echo "[Nezha-Init] 配置文件 config.yaml 已生成。"
else
  echo "[Nezha-Init] 配置文件已存在，跳过生成步骤。"
fi

echo "[Nezha-Init] 初始化流程结束。"