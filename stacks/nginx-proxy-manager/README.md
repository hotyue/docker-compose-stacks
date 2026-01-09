## Reverse Proxy Network

本 Stack 会创建一个名为 `proxy` 的 Docker bridge network。

后续所有需要通过 Nginx Proxy Manager 反代的服务：
- 加入同一个 `proxy` network
- 不必对外暴露端口
- 在 NPM 中使用容器名作为上游地址

示例：
http://service-name:8080