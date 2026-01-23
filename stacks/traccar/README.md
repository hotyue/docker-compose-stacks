# Traccar

Traccar GPS 设备管理与追踪服务。

## 特性

- 使用平台级 MariaDB
- 逻辑数据库与专属账号初始化
- 遵循 v1.1.13 数据库治理规范

## 端口

- Web UI: 8082
- 设备端口: 5000–5300 (TCP / UDP)


## Lifecycle (v1.2.0)

From v1.2.0, Traccar stack follows strict lifecycle governance:

- Database initialization is executed as an Installer task:
  - Task ID: `traccar.db.init`
  - Source: `tasks/traccar-db-init.sh`
- `docker-compose.yml` defines **runtime services only**
- No initialization or migration logic is allowed inside compose services

Lifecycle stages:

1. **prepare**
   - Execute `traccar.db.init`
2. **run**
   - Start `traccar` service via docker compose

Re-running Installer is safe and idempotent.
