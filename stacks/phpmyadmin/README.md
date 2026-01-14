# phpMyAdmin Stack
## 一、Stack 定位说明

本 Stack 提供 phpMyAdmin，用于对 外置的 MariaDB / MySQL 数据库进行可视化管理。

### 重要定位声明

- 本 Stack 仅作为数据库客户端工具

- 不创建、不管理、不初始化数据库

- 不定义、不修改数据库账号与权限

- 不依赖、不绑定任何应用 Stack

- 数据库实例被明确视为 平台级资源

## 二、适用场景

phpMyAdmin 适用于以下场景：

- 数据库结构查看与维护

- 表数据的可视化浏览与编辑

- SQL 查询与调试

- 数据库账号权限与会话状态检查

不适用于：

- 数据库部署

- 主从、集群、高可用等数据库架构管理

- 数据库初始化或迁移

## 三、安装与配置流程
### 1️⃣ 安装入口

在项目根目录执行：
```bansh
./install.sh
```

在菜单中选择 **phpMyAdmin** 。

### 2️⃣ 首次安装行为说明（重要）

在首次安装时：

  1. Installer 会将 .env.example 复制为运行目录中的 .env  
  2. 安装流程将自动暂停  
  3. 终端会提示你手动编辑该 .env 文件  

这是一个强制流程，用于确保数据库连接信息由用户显式提供。  

### 3️⃣ 配置 .env

编辑运行目录中的 .env 文件，例如：
```env
PMA_HOST=mariadb
PMA_PORT=3306
PMA_USER=db_admin
PMA_PASSWORD=change_me_db_admin_password
PMA_ARBITRARY=0
```

各配置项说明：

| 变量名  |  	说明 |
| -----  | ----- |
| PMA_HOST | 	数据库主机名或 IP |
| PMA_PORT | 	数据库端口（通常为 3306） |
| PMA_USER | 	默认管理账号（推荐使用 db_admin） |
| PMA_PASSWORD | 	登录数据库的密码 |
| PMA_ARBITRARY | 	是否允许任意服务器登录（建议保持 0） |


⚠️ 关于数据库账号的重要说明（v1.1.5 强制语义）

- 不推荐、也不默认使用 root 账号

- 推荐默认使用 平台级管理账号 db_admin

- db_readonly 账号不在 .env 中配置

如需验证只读权限，请在 phpMyAdmin 登录界面 手动输入：

- 用户名：db_readonly

- 密码：对应只读账号密码

该行为用于验证 MariaDB Stack 中已冻结的账号权限治理模型。

### 4️⃣ 继续安装

配置完成后，重新执行：
```bash
./install.sh
```

Installer 将继续完成安装并启动服务。

## 四、访问方式

phpMyAdmin 对外提供 HTTP 服务，端口固定映射为：
```cpp
http://<服务器IP>:8018
```
## 五、网络与连接说明

- phpMyAdmin 运行在项目既定的 proxy 外部 Docker 网络中

- 数据库实例必须满足以下任一条件：

    - 位于同一 Docker 网络

    - 或通过宿主机网络直接访问

## 六、账号与权限验证说明（v1.1.5 核心）

本 Stack 用于验证 v1.1.4 已冻结的 MariaDB 账号治理模型：

###使用 db_admin 登录：

- 可创建 / 删除数据库

- 可管理表结构

- 可执行写入与结构性操作

###使用 db_readonly 登录：

- 可执行 SELECT 查询

- INSERT / UPDATE / DELETE / DROP 等操作将被数据库权限拒绝

phpMyAdmin 不限制权限，  
权限行为完全由 MariaDB 数据库侧控制。

## 七、安全建议

- 强烈建议使用 非 root 数据库账号

- 生产环境中保持 PMA_ARBITRARY=0

- 如需公网访问，请自行在上层引入访问控制（如反向代理、认证、防火墙）

## 八、与其他 Stack 的关系

- phpMyAdmin 不是任何 Stack 的依赖

- 任何应用 Stack 不得反向依赖 phpMyAdmin

- 可与 MariaDB、Nezha、Matomo 等 Stack 并存，但职责完全隔离

## 九、卸载说明

phpMyAdmin 不持久化任何业务数据。

如需卸载：

- 停止并移除容器即可

- 不会影响数据库本身

## 十、版本与兼容性

- phpMyAdmin 镜像：phpmyadmin:5

- 兼容数据库：

    - MariaDB

    - MySQL

## 十一、责任边界声明

本 Stack：

- 不对数据库数据安全负责

- 不对误操作造成的数据损失负责

- 仅提供管理工具能力

请在使用前确保你理解并接受上述边界。