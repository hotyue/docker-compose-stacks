#!/usr/bin/env bash
set -euo pipefail

# =========================
# docker-compose-stacks bootstrap
# - 下载仓库到临时目录
# - 执行 install.sh
# - 默认使用 main；可通过环境变量 DCS_REF 指定 tag/分支（例如 v0.1.0）
# =========================

REPO_OWNER="${DCS_OWNER:-hotyue}"
REPO_NAME="${DCS_REPO:-docker-compose-stacks}"
REF="${DCS_REF:-main}"

# UTC 统一（与 installer 策略一致）
export TZ=UTC

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
  return 0
}

cleanup() {
  if [ -n "${WORKDIR:-}" ] && [ -d "${WORKDIR:-}" ]; then
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

echo "[$(ts)] docker-compose-stacks bootstrap"
echo "[$(ts)] repo: ${REPO_OWNER}/${REPO_NAME}, ref: ${REF}"

WORKDIR="$(mktemp -d)"
echo "[$(ts)] workdir: $WORKDIR"

download_with_git() {
  echo "[$(ts)] 使用 git 克隆仓库..."
  git clone --depth=1 --branch "$REF" "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" "$WORKDIR/repo" >/dev/null
}

download_with_tar() {
  echo "[$(ts)] 未检测到 git，使用 tarball 下载..."
  # GitHub tarball: https://github.com/<owner>/<repo>/archive/refs/heads/main.tar.gz
  # tag: https://github.com/<owner>/<repo>/archive/refs/tags/v0.1.0.tar.gz
  local url=""
  if [[ "$REF" == v* || "$REF" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/tags/${REF}.tar.gz"
  else
    url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${REF}.tar.gz"
  fi

  curl -fsSL "$url" -o "$WORKDIR/repo.tar.gz"
  mkdir -p "$WORKDIR/repo"
  tar -xzf "$WORKDIR/repo.tar.gz" -C "$WORKDIR"
  # 解压后目录名类似：repo-ref/
  local extracted
  extracted="$(find "$WORKDIR" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n 1)"
  if [ -z "$extracted" ]; then
    echo "[$(ts)] 解压失败：未找到 ${REPO_NAME}-* 目录"
    exit 1
  fi
  mv "$extracted" "$WORKDIR/repo"
}

main() {
  if ! need_cmd docker; then
    echo "[$(ts)] 缺少 docker，请先安装 Docker 与 Docker Compose。"
    exit 1
  fi

  if need_cmd git; then
    download_with_git
  else
    if ! need_cmd curl; then
      echo "[$(ts)] 缺少 git 且缺少 curl，无法下载仓库。"
      exit 1
    fi
    download_with_tar
  fi

  if [ ! -f "$WORKDIR/repo/install.sh" ]; then
    echo "[$(ts)] 未找到 install.sh，请确认 ref 是否正确：$REF"
    exit 1
  fi

  echo "[$(ts)] 执行 installer..."
  chmod +x "$WORKDIR/repo/install.sh"
  (cd "$WORKDIR/repo" && ./install.sh)
}

main "$@"
