# Matomo

Matomo 是一款开源的 Web 分析平台，用于替代 Google Analytics，支持完全自托管与数据自主控制。

本 Stack 提供 Matomo On-Premise 的 Docker Compose 部署方案，用于网站访问统计与用户行为分析。

## Stack 说明

本 Matomo Stack 具有以下明确边界与特性：

- 使用 官方 Matomo Docker 镜像

- 通过 Docker Compose 运行 Matomo 应用

- 不包含数据库服务

- 不管理数据库生命周期

- 不修改项目 Installer 的任何既有行为

- 不引入自定义安装脚本或运行时校验逻辑

本 Stack 仅负责 Matomo 应用及其归档任务的容器化运行。

## 架构与服务组成

本 Stack 由以下两个服务组成：

### matomo（主服务）

- 提供 Matomo Web 界面

- 对外暴露 HTTP 服务端口

- 通过环境变量注入数据库连接信息

- 显式禁用浏览器触发归档

### matomo-archive（后台归档服务）

- 使用与主服务相同的 Matomo 镜像

- 通过定时循环执行官方归档命令

- 默认每 1 小时执行一次归档

- 与主服务共享数据目录

两个服务均接入 外部 proxy 网络，用于统一反向代理接入。

## 一应用一逻辑数据库（强制语义）

Matomo 必须使用一个独立的逻辑数据库，并遵循以下约定：

- 逻辑数据库名称 必须为 matomo

- 该数据库 仅供 Matomo Stack 使用

- 不与任何其他应用共享逻辑数据库

该约定用于确保数据隔离、配置清晰性与平台级可维护性。

## 数据库实例职责说明

- MySQL / MariaDB 属于平台级资源

- 数据库实例：

    - 不由本 Stack 创建

    - 不由本 Stack 管理

    - 不由本 Stack 校验或迁移

- 本 Stack 仅通过环境变量连接并使用数据库

## 依赖说明

在启动 Matomo Stack 前，需满足以下前置条件：

- 已存在可用的 MySQL / MariaDB 实例

- 数据库实例中已预先完成：

    - 创建逻辑数据库 matomo

    - 创建对应的数据库用户并授权

- 已存在可用的 proxy 外部网络

    - 本 Stack 将直接加入该网络

    - 网络本身不由本 Stack 创建或管理

## 配置说明
### 配置入口声明

- 所有配置均通过 .env 文件提供

- .env.example 是 唯一配置声明入口

- docker-compose.yml 中不包含硬编码配置值

### Installer 行为说明（继承冻结事实）

首次安装流程遵循项目中已冻结的 Installer 行为：

    1. Installer 从 .env.example 生成 .env

    2. Installer 强制中断安装流程

    3. 用户自行补全并确认 .env 内容

    4. 重新执行安装后，服务启动

本 Stack 未引入任何 Installer 特判或流程分支。

## 数据库配置说明
### 平台级数据库准备（仅示意）

以下内容仅用于说明 数据库应如何在平台侧准备，不代表本 Stack 会执行相关操作：
```text
MARIADB_DATABASE=matomo
MARIADB_USER=matomo
MARIADB_PASSWORD=change_me_strong_matomo_password
```
### Matomo Stack 数据库连接配置

在 .env 中应配置如下变量：
```text
MATOMO_DB_HOST=mariadb
MATOMO_DB_PORT=3306
MATOMO_DB_NAME=matomo
MATOMO_DB_USER=matomo
MATOMO_DB_PASSWORD=change_me_strong_matomo_password
MATOMO_DB_PREFIX=matomo_
```
### 与 docker-compose 的对应关系

上述变量将被映射为 Matomo 官方支持的环境变量：
```text
MATOMO_DATABASE_HOST
MATOMO_DATABASE_DBNAME
MATOMO_DATABASE_USERNAME
MATOMO_DATABASE_PASSWORD
MATOMO_DATABASE_TABLES_PREFIX
```

本 Stack 不对数据库状态进行任何运行时校验。

## 后台归档（Archiving）说明

本 Stack 默认启用后台定时归档，用于提升报表加载性能，并避免浏览器按需归档带来的性能问题。

### 实现方式（与 compose 文件一致）

通过独立的 matomo-archive 服务

周期性执行官方命令：
```text
php /var/www/html/console core:archive --url=${MATOMO_BASE_URL}
```

默认执行周期：每 3600 秒（1 小时）

### 浏览器归档行为

主服务中已通过环境变量：
```text
MATOMO_CONFIG_General__browser_archiving_disabled_enforce=1
```

强制禁用浏览器触发归档

该行为为官方支持的配置注入方式

### 数据目录说明

./data 目录被挂载至：
```text
/var/www/html
```

主服务与归档服务共享该目录

该目录用于：

Matomo 程序文件

用户上传内容

归档数据与配置

## 注意事项

Matomo Stack 不管理数据库生命周期

请确保数据库实例在 Matomo 启动前已可用

后台归档任务依赖正确配置的 MATOMO_BASE_URL

本 Stack 不对反向代理、证书或域名配置做任何假设

## 兼容性与行为声明

本 Stack 完全继承项目中已冻结的 Installer 行为

未引入任何新功能或运行时校验

未修改数据库部署模型

与 v1.0.x 版本保持向后兼容

### 本文档为 Matomo Stack 在 v1.1.0 版本中的语义升级说明文本。