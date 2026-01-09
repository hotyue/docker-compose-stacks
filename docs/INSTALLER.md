# Installer 设计说明

本文档说明本仓库中 `install.sh` 的设计目标、职责边界与扩展原则。

---

## 一、Installer 的定位

Installer 的职责是 **调度（orchestration）**，而不是部署逻辑本身。

它只负责：

- 发现可安装的应用栈
- 与用户进行交互式选择
- 创建必要的共享资源（如 Docker network）
- 调用对应 Stack 的 `docker compose up -d`
- 记录已安装状态

Installer **不会**：

- 修改任何 `docker-compose.yml`
- 注入或 patch 配置文件
- 管理应用内部逻辑
- 假设应用的启动顺序

---

## 二、发现机制：stack.meta

### 1️⃣ 发现规则

Installer 会扫描：  
stacks/**/stack.meta

任何包含 `stack.meta` 的目录，都被视为一个 **可独立安装的 Stack**。

因此：

- `stacks/nezha/server`
- `stacks/nezha/agent`

会被识别为两个不同的安装单元。

---

### 2️⃣ stack.meta 格式

`stack.meta` 使用 bash 友好的 `KEY="VALUE"` 格式，可被直接 `source`。

示例：

```ini
NAME="Nginx Proxy Manager"
CATEGORY="reverse-proxy"
DESCRIPTION="Web UI 管理 Nginx 反向代理与 HTTPS"
REQUIRES_NETWORK="proxy"
DEFAULT_ENABLE=true
```

字段说明:

| 字段               | 说明           |
| ---------------- | ------------ |
| NAME             | 菜单中展示的名称     |
| CATEGORY         | 分类（仅用于展示与分组） |
| DESCRIPTION      | 一句话说明        |
| REQUIRES_NETWORK | 依赖的共享网络      |
| DEFAULT_ENABLE   | 是否推荐默认安装     |


---

## 三、共享资源管理
Docker Network

- proxy 被定义为 仓库级共享网络

- 由 Installer 创建

- Stack 通过 external: true 使用

Installer 逻辑示意：
```bash
docker network inspect proxy || docker network create proxy
```

Stack 不应假设该网络一定存在。

---

## 四、已安装状态管理

Installer 使用仓库根目录下的文件：  
```text
.installed
```

用于记录 **当前环境中已安装的 Stack 目录路径**。

### 设计说明

- `.installed` 属于 **运行态状态文件**
- 不应被提交到仓库
- 已加入 `.gitignore`

### Installer 使用方式

- 安装完成后，自动记录已安装 Stack
- 再次运行 Installer 时：
  - 在菜单中标记“已安装”
  - 防止重复安装

### 注意事项

- 删除 `.installed` 不会卸载任何服务
- 仅会重置 Installer 的“已安装”判断
- 实际容器与数据需用户自行管理


---

## 五、时区策略（Timezone）

 1️⃣ Installer 脚本统一使用 UTC

- 用于日志与状态记录

- 避免地域歧义

 2️⃣ 应用运行时的时区：

- 由 Stack 自行定义

- 通过 .env 或环境变量控制

---

## 六、运行时目录与权限规范（冻结）

Installer 在运行时目录创建与权限处理方面，**必须严格遵循以下冻结规范**：

📄 **《Installer 运行时目录与权限规范》**  
路径：`docs/INSTALLER_RUNTIME.md`

该规范明确约束了：

- 所有 Stack 的运行时目录统一位于：  
/opt/docker/<stack-id>  
- Installer 在权限处理上的**职责边界**
- 运行时目录**必须对容器进程可写**
- 明确禁止基于固定 UID/GID 的 `chown` 行为

### 规范优先级说明

- 本规范为 **冻结规范（Frozen）**
- 对所有 Installer 行为具有 **强制约束力**
- 任何 Installer 相关修改，如与该规范冲突，**视为无效修改**
- 如需调整，必须通过明确的规范修订讨论，而非临时修补

### 职责边界总结

Installer 的职责仅限于：

> **保证运行时目录可被容器写入，  
而不决定容器以何种用户运行。**

---

## 七、设计原则总结

- Installer 负责“调度”，Stack 负责“运行”

- 所有 Stack 必须可被独立运行

- 不引入隐式依赖或魔法行为

- 优先可读性与可维护性，而非功能堆叠

---

## 八、未来可能的扩展方向

- 多选安装

- 卸载已安装 Stack

- 非交互式模式（CI / 自动化）

- 全局变量收集（如统一 TZ）

这些扩展 不会改变现有 Stack 结构。
