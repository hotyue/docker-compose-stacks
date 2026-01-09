# 哪吒监控（Agent）

部署在被监控服务器上的客户端。

## 启动前准备

需要在环境变量中提供：

- NEZHA_SERVER：服务端地址（域名或 IP）
- NEZHA_CLIENT_SECRET：客户端密钥

## 启动方式

```bash
export NEZHA_SERVER=example.com:443
export NEZHA_CLIENT_SECRET=xxxxxx
docker compose up -d
