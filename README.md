# Docker Compose Stacks

![License](https://img.shields.io/github/license/hotyue/docker-compose-stacks)
![Release](https://img.shields.io/github/v/release/hotyue/docker-compose-stacks)
![Last Commit](https://img.shields.io/github/last-commit/hotyue/docker-compose-stacks)
![Repo Size](https://img.shields.io/github/repo-size/hotyue/docker-compose-stacks)
![Installer](https://img.shields.io/badge/installer-bash-blue)
![Installer Mode](https://img.shields.io/badge/installer-orchestrator-brightgreen)
![Config First](https://img.shields.io/badge/configuration-config--first-blueviolet)
![Docker](https://img.shields.io/badge/docker-compose-blue)

这是一个 **有版本发布、以配置为先、由 Bash Installer 统一调度的** Docker Compose 自托管应用仓库。  

本仓库的目标不是堆模板，而是提供一个 **可扩展、可维护、可一键安装** 的基础设施级方案。

---

## 特性（Features）

- 📦 一应用一 Stack，结构清晰
- 🧩 支持 Server / Agent 等多角色拆分
- 🚀 提供交互式 Installer，一键安装
- 🔁 统一反向代理网络（`proxy`）
- 🌍 Installer 统一使用 UTC，具备国际化基础
- 🛠 仅依赖 Docker / Docker Compose，无额外运行时

---

## 📦 版本与变更记录

本项目的所有**已发布版本变更事实**，均记录在 [`CHANGELOG.md`](./CHANGELOG.md) 中。

该文件仅包含：

- 已完成并冻结的实现
- 已验证并确认成立的功能与治理结论

不记录：

- 计划中的功能
- 未完成或已被终止的实现

CHANGELOG.md 是本项目**版本演进事实的唯一权威入口**。

---

## 快速开始（Quick Start）

本仓库提供两种使用方式：

- **快速安装（推荐）**：适合普通用户（无需 git）
- **克隆仓库运行**：适合开发者或贡献者

### 方式 A：快速安装（推荐）

> 说明：该命令会下载并运行 Installer。  
> 建议先查看脚本内容再执行（下方提供查看方式）。

直接运行（交互式）：

```bash
curl -fsSL https://raw.githubusercontent.com/hotyue/docker-compose-stacks/main/scripts/bootstrap.sh -o bootstrap.sh
bash bootstrap.sh

```

安装指定版本（可复现）：

```bash
curl -fsSL https://raw.githubusercontent.com/hotyue/docker-compose-stacks/main/scripts/bootstrap.sh -o bootstrap.sh
DCS_REF=v1.1.12 bash bootstrap.sh

```
先下载再查看（更安全）：

```bash
curl -fsSL https://raw.githubusercontent.com/hotyue/docker-compose-stacks/main/scripts/bootstrap.sh -o bootstrap.sh
less bootstrap.sh
bash bootstrap.sh
```

### 方式 B：克隆仓库运行（开发者/贡献者）

```bash
git clone https://github.com/hotyue/docker-compose-stacks.git
cd docker-compose-stacks
./install.sh
```

Installer 将会：

- 自动扫描所有可用应用栈（基于 stack.meta）

- 显示应用名称 / 分类 / 描述 / 依赖（如 proxy）

- 在安装前给出确认摘要

- 自动创建所需的 Docker network（如 proxy）

- 自动生成 .env（如存在 .env.example）

- 在安装阶段复制并准备初始化资源（如数据库初始化脚本）

- 记录已安装状态，避免重复安装

---

## 当前可用应用栈（Stacks）  
> 以下列表由 Installer 基于 stack.meta 自动生成，反映当前版本中**可用且受支持的 Stack**。

<!-- STACKS:START -->

### 反向代理

- **Nginx Proxy Manager**  
  Web UI 管理 Nginx 反向代理与 HTTPS 证书

### 监控

- **Matomo**  
  开源的自托管 Web 分析平台，用于替代 Google Analytics
- **哪吒监控（Agent）**  
  哪吒监控客户端，用于被监控节点
- **哪吒监控（Server）**  
  哪吒监控面板与 API 服务端

### 数据库

- **MariaDB**  
  MariaDB 单机数据库服务（容器化），内置初始化治理与平台级账号模型，适用于通用业务数据存储.

### 安全

- **Vaultwarden**  
  轻量级 Bitwarden 兼容自托管密码管理服务端，支持 WebSocket 通知通道

### 工具

- **phpMyAdmin**  
  基于 Web 的 MariaDB / MySQL 数据库管理工具
- **Traccar**  
  Traccar GPS 追踪服务 (Osmand 协议优化版)
- **WordPress**  
  WordPress 内容管理系统（外置数据库）

<!-- STACKS:END -->

---

## Installer 设计说明（重要）

本仓库的 Installer 设计遵循以下原则：

### 1️⃣ Installer 负责调度

- 扫描 stack.meta

- 创建共享资源（如 Docker network）

- 启动并记录已安装应用

### 2️⃣ Stack 自身必须自洽

- 不假设安装顺序

- 不修改 Compose 内容

- 可被独立运行或由 Installer 调度

---

### 3️⃣ stack.meta

每个可安装应用栈都包含一个 stack.meta 文件，用于描述：

- 展示名称

- 分类

- 简要说明

- 依赖的共享资源（如 proxy）

Installer 通过该文件实现 零硬编码发现与调度。

---

## 目录结构

```text
.
├── install.sh                # 交互式 Installer
├── stacks/                   # 应用栈集合
│   ├── nginx-proxy-manager/  # NPM反代面板
│   ├── nezha/                # nezha VPS监控面板
│   │   ├── server/
│   │   └── agent/
│   ├── vaultwarden/          # Vaultwarden（Bitwarden 兼容服务端）
│   │   └── server/
│   ├── matomo/               # WEB访问统计面板
│   ├── mariadb/              # 数据库
│   ├── phpMyAdmin/           # 数据库管理工具
│   ├── wordpress/            # 一款blog系统
│   └── _template/
├── docs/                     # 设计与规范文档
├── .installed                # 已安装记录（Installer 使用）
└── README.md
```

---

## 时区说明（Timezone）

### 1️⃣ Installer 脚本统一使用 UTC

- 用于日志与状态记录

### 2️⃣ 各应用栈运行时的时区：

- 由各自的 .env 控制

- 默认给出合理示例值

- 用户可自行修改

---

## 适用人群

- 自托管 / VPS 用户

- 希望统一管理多个服务的个人或小团队

- 不想维护复杂 Ansible / K8s，但又需要结构化部署方案的用户

---

## 项目治理与长期原则

本项目的长期架构原则与演进边界由《项目宪法（Constitution v1.0）》定义。

- 宪法用于约束架构级决策
- 所有重大设计变更均不得违反宪法

📜 详见：[`docs/CONSTITUTION.md`](docs/CONSTITUTION.md)

---

## 免责声明（Disclaimer）

本仓库提供的是部署示例与安装工具，而非完整安全方案。

请在生产环境中自行评估并配置：

- 防火墙

- 访问控制

- 备份与监控

- HTTPS / WAF / 身份验证策略

---

## 后续计划（Roadmap）  
> 以下内容为非承诺性方向性设想，不构成版本计划或实现承诺。

- Installer 多选安装 / 卸载

- 非交互式（CI / 自动化）模式

- 更多常见自托管应用栈

欢迎 Issue 与 PR。

---

## Stargazers over time
[![Stargazers over time](https://starchart.cc/hotyue/docker-compose-stacks.svg?variant=adaptive)](https://starchart.cc/hotyue/docker-compose-stacks)

