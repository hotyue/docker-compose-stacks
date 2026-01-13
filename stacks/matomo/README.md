# Matomo

Matomo 是一款开源的 Web 分析平台，用于替代 Google Analytics，支持完全自托管与数据自主控制。

## Stack 说明

本 Stack 提供 **Matomo On-Premise 的 Docker Compose 部署方案** ，用于网站访问与用户行为分析。

该 Stack：

- 使用官方 Matomo 镜像

- 不包含数据库服务

- 不修改项目 Installer 的任何行为

- 不引入自定义安装或配置脚本

## 依赖说明

- 本 Stack **不包含数据库** 

- 需提前准备可用的 **MySQL / MariaDB** 实例

- 数据库连接信息由 .env 提供

- 需接入已存在的 proxy 外部网络

## 配置说明

所有配置均通过 .env 文件提供，.env.example 为唯一配置声明入口。

首次安装流程遵循项目既有冻结行为：

- Installer 从 .env.example 生成 .env

- Installer **强制中断安装流程** 

- 用户自行补全并确认 .env 内容

- 重新执行安装后，服务启动


### ========== 数据库配置 ==========
Matomo 使用的 MySQL / MariaDB 数据库  
下边这一段来自 mariadb/.env.example
```text
# 可选：初始化库与用户（如果不需要可留空或删除这三行）
MARIADB_DATABASE=app
MARIADB_USER=app
MARIADB_PASSWORD=change_me_strong_app_password
```
你之前安装 mariadb 时如何配置的上述内容；  
这里你就要对应的修改；  
```text
MATOMO_DB_HOST=mariadb
MATOMO_DB_NAME=app
MATOMO_DB_USER=app
MATOMO_DB_PASSWORD=change_me_strong_app_password
MATOMO_DB_PREFIX=matomo_
```

## 后台归档（Archiving）说明

本 Stack **默认启用后台定时归档** ，用于提升报表加载性能并避免浏览器按需归档带来的性能问题。

实现方式：

- 通过独立的后台归档服务定期执行 Matomo 官方归档命令

- 归档周期为 **每小时一次**

同时，本 Stack 已 **强制禁用浏览器触发归档行为** ，以避免高访问量场景下的性能问题。

如需恢复浏览器触发归档，可在 docker-compose.yml 中移除对应的配置项。

## 注意事项

- Matomo Stack 本身不管理数据库生命周期

- 请确保数据库实例在 Matomo 启动前可用

- 后台归档任务依赖正确配置的 MATOMO_BASE_URL

## 兼容性与行为声明

- 本 Stack 完全继承项目中已冻结的 Installer 行为

- 未引入任何 Installer 特判或安装流程分支

- 所有运行时行为均通过 Docker Compose 显式声明

以上内容即为 **v1.0.4 版本中 Matomo Stack 的完整说明。** 
