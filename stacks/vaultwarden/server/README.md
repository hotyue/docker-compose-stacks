# Vaultwarden (server)

本 Stack 部署 Vaultwarden（Bitwarden 兼容服务端），使用平台级 MariaDB 作为外置数据库，并通过 Nginx Proxy Manager（NPM）提供 HTTPS 反向代理。

## 部署方式（两阶段）

1. 首次运行：复制 `.env.example` 为 `.env` 并修改其中的密码与域名
2. 第二次运行：执行部署，init 容器将自动创建数据库与专用用户，然后启动 vaultwarden

## 端口裁定

- Vaultwarden 内部监听端口：8038（强制）
- 可选映射宿主机端口：8038（用于直连验证）
- 推荐最终通过 NPM 以 HTTPS 访问（对外 TLS 由 NPM 终止）

## WebSocket（通知通道）裁定

- WebSocket 默认启用（最佳体验）
- WebSocket 与 HTTP API 同端口（8038），无需单独端口

### NPM 配置要求（必须）

在 Nginx Proxy Manager 中创建 Proxy Host：
- Forward Hostname：`vaultwarden`
- Forward Port：`8038`
- 启用 WebSocket Support
- SSL：申请/配置证书并强制 HTTPS（建议）

### Cloudflare 场景

以下组合裁定为支持：
- Docker 部署 + NPM 反代 + Cloudflare 橙云（CDN/代理）+ WebSocket
- Docker 部署 + NPM 反代 + Cloudflare Zero Trust Tunnel + WebSocket

说明：
- WebSocket 异常仅影响“实时通知/同步体验”，不影响核心功能（可退化为轮询）。
