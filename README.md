# Docker Compose Stacks

一组 **可直接复制使用（copy-paste ready）** 的 Docker Compose 应用栈合集，面向：

- VPS / 云服务器
- 自托管（self-hosted）
- Homelab / 个人基础设施

目标：**结构统一、默认可运行、生产环境不踩坑**。

---

## Features

- 📦 一应用一目录，结构清晰
- 🚀 快速启动，复制即用
- 🔒 默认避免暴露不必要端口
- 🔁 适合与反向代理 / Cloudflare 搭配
- 🧱 可持续扩展，不会越用越乱

---

## Quick Start

所有应用栈遵循相同启动流程：

```bash
git clone https://github.com/hotyue/docker-compose-stacks.git
cd docker-compose-stacks/stacks/<stack-name>
cp .env.example .env
docker compose up -d
```  

注意：
.env.example 仅为示例，不包含任何敏感信息。
.env 文件 不会 被提交到仓库。

Available Stacks
Reverse Proxy

nginx-proxy-manager
Web UI 方式管理 Nginx 反向代理与 HTTPS 证书

Monitoring

nezha（即将加入）
VPS 监控与状态面板

Panel / Services

3x-ui（即将加入）
网络服务管理面板示例

每个 Stack 目录内均包含独立的 README.md，说明用途、端口与注意事项。

Repository Structure
.
├── docs/                 # 通用文档（安全 / 反代 / 约定）
├── stacks/               # 应用栈集合
│   ├── nginx-proxy-manager/
│   ├── nezha/
│   ├── 3x-ui/
│   └── _template/        # 新应用模板
├── .gitignore
├── .editorconfig
└── README.md

Conventions

请在使用或贡献前阅读：

📐 目录与命名规范：docs/conventions.md

🔐 安全建议：docs/security.md

🔁 反向代理通用说明：docs/reverse-proxy.md

核心约定摘要：

不提交 .env、证书、密钥或数据库数据

使用 restart: unless-stopped

优先通过反向代理访问服务，而非直接暴露端口

Security Notes

本仓库提供的是 部署示例，而非开箱即用的“安全方案”。

使用前请务必自行完成：

系统防火墙配置

面板访问控制

HTTPS / WAF / 访问策略

生产环境强烈建议配合反向代理与额外的访问限制机制。

Contributing

欢迎提交 Issue 或 Pull Request：

新增应用栈

改进现有 Compose 配置

补充文档或排坑说明

请遵循已有目录结构与命名约定。

Disclaimer

本仓库内容仅供学习与参考。
使用者需自行评估由此产生的任何风险与责任。
