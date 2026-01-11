### 配置文件（.env 文件）

在安装过程中，Installer 会自动复制 `.env.example` 文件为 `.env`。请根据以下说明修改 `.env` 文件中的配置项：

- **MARIADB_ROOT_PASSWORD**: 设置 MariaDB root 用户的密码（默认：`change_me_strong_root_password`）。
- **MARIADB_DATABASE**: 设置需要初始化的数据库名称（可选）。
- **MARIADB_USER**: 设置创建的数据库用户（可选）。
- **MARIADB_PASSWORD**: 设置数据库用户的密码（可选）。

注意：修改后请保存 `.env` 文件，然后再继续执行安装过程。
