#!/usr/bin/env bash
set -e

# ==============================================================================
# Nezha Server 数据库初始化 (MariaDB 11 专用版)
# ==============================================================================

echo "[Init] 正在尝试连接数据库..."
echo "       Host: ${NEZHA_DB_HOST}"
echo "       User: ${NEZHA_DB_ADMIN_USER}"

# 1. 数据库存活检测 (使用 mariadb 客户端 + 显式 TCP 协议)
# ------------------------------------------------------------------------------
# 废弃 mariadb-admin ping，改用 SELECT 1
# 强制使用 --protocol=tcp 避免本地 socket 解析干扰

MAX_RETRIES=30
COUNT=0

while true; do
    # 尝试执行查询，同时捕获标准输出和错误输出
    if mariadb -h "${NEZHA_DB_HOST}" -P "${NEZHA_DB_PORT}" -u "${NEZHA_DB_ADMIN_USER}" -p"${NEZHA_DB_ADMIN_PASSWORD}" --protocol=tcp -e "SELECT 1" >/dev/null 2>&1; then
        echo "[Init] 数据库连接成功！"
        break
    fi

    echo "  - 连接失败 (重试 $COUNT/$MAX_RETRIES)..."
    
    # 每 3 次重试，打印一次真实的错误报错，不再瞎猜
    if [ $((COUNT % 3)) -eq 0 ]; then
        echo "    [DEBUG 错误详情]:"
        mariadb -h "${NEZHA_DB_HOST}" -P "${NEZHA_DB_PORT}" -u "${NEZHA_DB_ADMIN_USER}" -p"${NEZHA_DB_ADMIN_PASSWORD}" --protocol=tcp -e "SELECT 1" || true
        echo "    -------------------"
    fi

    sleep 2
    COUNT=$((COUNT+1))
    
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "[Init] ❌ 错误：无法连接到 MariaDB，请检查上方 DEBUG 信息。"
        exit 1
    fi
done

# 2. 数据库初始化
# ------------------------------------------------------------------------------
echo "[Init] 正在执行 SQL 初始化..."

mariadb \
  -h "${NEZHA_DB_HOST}" \
  -P "${NEZHA_DB_PORT}" \
  -u "${NEZHA_DB_ADMIN_USER}" \
  -p"${NEZHA_DB_ADMIN_PASSWORD}" \
  --protocol=tcp <<SQL

CREATE DATABASE IF NOT EXISTS \`${NEZHA_DB_NAME}\`
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${NEZHA_DB_USER}'@'%'
  IDENTIFIED BY '${NEZHA_DB_PASSWORD}';

-- MariaDB 11 必须显式刷新权限，且 ALTER USER 确保密码同步
ALTER USER '${NEZHA_DB_USER}'@'%'
  IDENTIFIED BY '${NEZHA_DB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${NEZHA_DB_NAME}\`.* TO '${NEZHA_DB_USER}'@'%';

FLUSH PRIVILEGES;

SQL

echo "[Init] 数据库权限已同步。"

# 3. 生成 config.yaml
# ------------------------------------------------------------------------------
CONFIG_DIR="/dashboard/data"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[Init] 正在生成 config.yaml (MySQL模式)..."
  
  cat > "$CONFIG_FILE" <<EOF
debug: false
language: zh-CN
site_name: Nezha Monitoring
httpport: ${NEZHA_HTTP_PORT:-8008}
grpcport: ${NEZHA_GRPC_PORT:-5555}
type: mysql
db: "${NEZHA_DB_USER}:${NEZHA_DB_PASSWORD}@tcp(${NEZHA_DB_HOST}:${NEZHA_DB_PORT})/${NEZHA_DB_NAME}?charset=utf8mb4&parseTime=True&loc=Local"
EOF

  chmod 666 "$CONFIG_FILE"
  echo "[Init] 配置文件 config.yaml 生成完毕。"
else
  echo "[Init] 配置文件已存在，跳过生成。"
fi

echo "[Init] 初始化流程结束。"