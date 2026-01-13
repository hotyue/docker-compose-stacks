# phpMyAdmin Stack
## 一、Stack 定位说明

本 Stack 提供 phpMyAdmin，用于对 外置的 MariaDB / MySQL 数据库进行可视化管理。

### 重要定位声明

- 本 Stack 仅作为数据库客户端工具

- 不创建、不管理、不初始化数据库

- 不依赖、不绑定任何应用 Stack

- 数据库实例被明确视为 平台级资源

## 二、适用场景

phpMyAdmin 适用于以下场景：

- 数据库结构查看与维护

- 表数据的可视化浏览与编辑

- SQL 查询与调试

- 用户权限与会话检查

不适用于：

- 数据库部署

- 数据库高可用 / 主从 / 集群

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
PMA_USER=example_user
PMA_PASSWORD=example_password
PMA_ARBITRARY=0
```

各配置项说明：

| 变量名  |  	说明 |
| -----  | ----- |
| PMA_HOST | 	数据库主机名或 IP |
| PMA_PORT | 	数据库端口（通常为 3306） |
| PMA_USER | 	登录数据库的用户名 |
| PMA_PASSWORD | 	登录数据库的密码 |
| PMA_ARBITRARY | 	是否允许任意服务器登录（建议保持 0） |
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

- 数据库必须：

    - 位于同一 Docker 网络
      或

    - 通过宿主机网络可达

## 六、安全建议

- 强烈建议使用 非 root 数据库账号

- 生产环境中保持 PMA_ARBITRARY=0

- 如需公网访问，请自行在上层引入访问控制（如反向代理、认证）

## 七、与其他 Stack 的关系

- phpMyAdmin 不是任何 Stack 的依赖

- 任何应用 Stack 不得反向依赖 phpMyAdmin

- 可与 MariaDB、Nezha、Matomo 等 Stack 并存，但职责完全隔离

## 八、卸载说明

phpMyAdmin 不持久化任何业务数据。

如需卸载：

- 停止并移除容器即可

- 不会影响数据库本身

## 九、版本与兼容性

- phpMyAdmin 镜像：phpmyadmin:5

- 兼容数据库：

    - MariaDB

    - MySQL

## 十、责任边界声明

本 Stack：

- 不对数据库数据安全负责

- 不对误操作造成的数据损失负责

- 仅提供管理工具能力

请在使用前确保你理解并接受上述边界。