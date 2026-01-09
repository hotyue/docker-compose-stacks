# <Stack Name>

> 本 Stack 不在目录名中包含版本信息。  
> 默认版本请查看 docker-compose.yml 或 .env.example。  
> 如需升级或切换版本，请修改对应的 Docker image tag 或环境变量。

---

## 运行目录规范

本 Stack 的运行时数据将位于：

/opt/docker/<stack-id>/

docker-compose.yml 中请仅使用相对路径挂载。


---

## Quick Start

```bash
cp .env.example .env
docker compose up -d
```

---