# Matomo

Matomo 是一款开源的 Web 分析平台，用于替代 Google Analytics，支持完全自托管。

## 依赖说明

- 本 Stack **不包含数据库**
- 需提前准备可用的 MySQL / MariaDB 实例
- 数据库连接信息由 `.env` 提供

## 安装说明

本 Stack 通过项目统一的 Installer 安装。

首次安装时：

- Installer 会从 `.env.example` 生成 `.env`
- 随后 **强制中断安装流程**
- 用户需自行补全并确认 `.env` 内容
- 重新执行安装后，服务才会启动

以上行为为项目既有冻结事实的一部分。
