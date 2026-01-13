# nginx-proxy-manager（外置数据库版）

本 Stack 提供基于 nginx-proxy-manager 的反向代理管理服务，
自 v1.1.2 起，其数据库后端 不再使用内置数据库，统一切换为 外置 MariaDB / MySQL。

## 一、架构与职责边界
### 1. 数据库架构定位

- 数据库被视为 平台级资源

- nginx-proxy-manager 仅作为数据库使用方

- 本 Stack 不创建、不管理、不初始化、不迁移 数据库

数据库需在部署本 Stack 之前，由平台或运维侧完成准备。

### 2. 数据库语义约束（强制）

- 一应用一逻辑数据库

- nginx-proxy-manager 使用 独立逻辑数据库

- 不与其他 Stack 共享数据库或 Schema

## 二、数据库配置说明
### 1. 支持的数据库类型

- MariaDB

- MySQL

版本与高可用策略不在本 Stack 职责范围内。

### 2. 数据库连接变量（通过 .env 注入）

所有数据库连接信息 必须 通过 .env 文件注入，
docker-compose.yml 中 不允许硬编码任何凭据。

#### 变量列表
| 变量名  |  	说明  |
| ------ | ------ |
| NPM_DB_HOST | 	数据库服务器地址 |
| NPM_DB_PORT | 	数据库端口（通常为 3306） |
| NPM_DB_USER | 	数据库用户名（需预先存在） |
| NPM_DB_PASSWORD | 	数据库用户密码 |
| NPM_DB_NAME	 | nginx-proxy-manager 专用逻辑数据库名 |

.env.example 文件仅作为变量语义模板，不提供可直接运行的默认值。

## 三、数据持久化说明
### 1. Volume 定义
```text
./data
└─ nginx-proxy-manager 运行数据（不含数据库）

./letsencrypt
└─ SSL 证书与 ACME 相关数据
```
### 2. 数据职责划分

- 数据库数据：存储于外置 MariaDB / MySQL

- 应用运行与证书数据：存储于本地 volume

## 四、网络说明

- 本 Stack 使用外部网络 proxy

- proxy 网络需提前创建

- 本 Stack 不负责网络创建或管理

## 五、升级与兼容性说明（重要）
### 1. 关于旧版本（内置数据库）

- v1.1.2 不提供 内置数据库模式

- 从旧版本升级时：

    - 数据迁移 不在本 Stack 职责范围内

    - 用户需自行完成数据导出 / 导入

### 2. 非破坏性原则

- 本 Stack 不修改 Installer 行为

- 不对既有 Stack 产生隐式破坏

- 不引入不可逆迁移流程

## 六、适用范围声明

本 Stack 的实现与说明 仅适用于 v1.1.2 及以后版本，
并严格受以下上位约束：

- 项目宪法窗口

- 项目总事实账本窗口（含 v1.1.1 冻结增量）

- v1.1.2 版本功能目标窗口

- v1.1.2 版本开发实现窗口

## 七、启动前检查清单

在启动 nginx-proxy-manager 前，请确认：

- 数据库实例已运行

- 数据库用户已创建

- 逻辑数据库已创建

- .env 文件已按实际环境填写

- proxy 网络已存在