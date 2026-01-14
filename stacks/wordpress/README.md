# WordPress Stack

本 Stack 提供 WordPress 服务编排能力，并采用外置 MariaDB / MySQL 数据库。

## 数据库模型

- 数据库实例属于平台级资源
- 本 Stack 不负责数据库实例的创建或管理
- 一个 WordPress Stack 对应一个独立的逻辑数据库与数据库用户

## 初始化机制

- 启动时会运行一次 `wp-db-init` 初始化容器
- 初始化内容包括：
  - 创建 WordPress 专属逻辑数据库
  - 创建专属数据库用户
  - 授权该用户仅访问其数据库
- 初始化脚本具备幂等性，可重复执行

## 运行期行为

- WordPress 运行期仅使用最小权限数据库账号
- 初始化阶段使用的管理账号不会参与运行期

## 使用方法

```bash
cp .env.example .env
docker compose up -d
