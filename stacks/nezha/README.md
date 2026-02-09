# Nezha Server（外置数据库版本）

本 Stack 用于部署 Nezha Server，并在 v1.1.1 版本中明确要求使用外置 MariaDB / MySQL 数据库。

## 一、数据库架构语义说明（重要）

### 数据库职责边界

- Nezha Server 不再使用任何内置数据库

- 数据库实例：

    - 视为平台级资源

    - 必须提前创建

    - 不由本 Stack 创建、初始化或迁移

- 本 Stack 仅负责使用数据库连接信息

### 一应用一逻辑数据库

- Nezha Server 必须使用独立的逻辑数据库

- 数据库语义要求：

    - 不与其他 Stack 共享

    - 逻辑数据库名称与 Stack 语义保持一致

- 推荐数据库名：nezha

## 二、环境变量配置


### 创建环境变量文件

执行以下命令：

cp .env.example .env

### 关键数据库变量说明

变量名说明如下：
```text
NEZHA_DB_HOST 数据库地址
NEZHA_DB_PORT 数据库端口
NEZHA_DB_NAME 逻辑数据库名称
NEZHA_DB_USER 数据库用户名
NEZHA_DB_PASSWORD 数据库密码
NEZHA_DB_CHARSET 数据库字符集
NEZHA_DB_TIMEZONE 数据库时区
```
所有数据库变量均通过 .env 文件注入，
不会在 docker-compose.yml 中硬编码。

## 三、网络与端口说明

- Nezha Server 默认监听容器内 8008 端口

- 该端口必须对外暴露，以供 Nezha Agent 访问

- 本 Stack 使用外部 Docker 网络：

    - proxy（external: true）

    - 网络由平台统一管理，不由本 Stack 创建

## 四、启动方式


在确认数据库实例已存在且连接信息正确后，执行：

docker compose up -d


## 五、重要限制声明（请务必阅读）


本 Stack 明确不会执行以下行为：

- 创建数据库或用户

- 初始化或迁移数据库 schema

- 校验数据库版本或状态

- 引入数据库高可用、主从或代理组件

- 修改 Installer 的职责或行为

数据库的生命周期与高可用策略
完全由平台层负责。


## 六、版本说明


- 本实现适用于版本：v1.1.1

- 对 v1.1.0 及之前版本的已冻结事实不构成任何影响