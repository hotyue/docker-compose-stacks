# Reverse Proxy

本仓库优先提供 Nginx Proxy Manager（NPM）场景的反代建议。

通用建议：
- 优先使用同一 Docker network 互通（反代容器与目标容器加入同一 network）
- 能不暴露目标容器端口就不暴露，仅在反代网络内部访问
