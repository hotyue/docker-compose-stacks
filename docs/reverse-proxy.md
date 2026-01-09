# 反向代理与 proxy 网络规范

本文档定义本仓库中 **反向代理的统一接入方式**，  
同时作为未来安装脚本（installer）的行为依据。

---

## 一、proxy 网络的定位

- `proxy` 是一个 **Docker bridge 网络**
- 用于：
  - 反向代理容器（如 Nginx Proxy Manager）
  - 被反代的业务容器
- `proxy` 是 **仓库级共享资源**，不是某个应用私有资源

约定：

- 网络名固定为：`proxy`
- 所有需要被反向代理访问的服务，必须加入该网络

---

## 二、为什么要使用 proxy 网络

统一使用 `proxy` 网络可以带来：

- 不暴露业务端口到宿主机
- 通过容器名进行反代（无需 IP）
- 多个服务可被同一个反代入口管理
- installer 可自动创建与检测该网络

---

## 三、反向代理容器的要求（以 NPM 为例）

反向代理类 Stack 必须：

- 创建或使用 `proxy` 网络
- 对外仅暴露 80 / 443 等必要端口
- 不依赖宿主机 IP 或 localhost

示意（简化）：

```yaml
services:
  proxy:
    networks:
      - proxy

networks:
  proxy:
    name: proxy  
```