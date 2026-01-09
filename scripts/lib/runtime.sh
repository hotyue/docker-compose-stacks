#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# Runtime Capability Detection Layer
#
# This file is responsible ONLY for detecting
# runtime capabilities and exporting normalized
# command variables for the installer.
#
# It MUST NOT:
# - contain installer flow logic
# - contain stack-specific logic
# - perform installation or mutation
# ==================================================

detect_compose() {
  # Prefer Docker Compose v2 (docker compose)
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
  # Fallback to legacy Docker Compose v1 (docker-compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
  else
    echo "❌ 未检测到 Docker Compose（v1 或 v2）"
    echo "请先安装 Docker Compose 后再运行 Installer"
    exit 1
  fi

  export COMPOSE_CMD
}
