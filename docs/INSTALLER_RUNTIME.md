# Installer 运行时目录与权限规范

状态：冻结（Frozen）
适用范围：docker-compose-stacks Installer（install.sh、bootstrap.sh）
生效版本：自 /opt/docker 运行时模型引入起

## 一、规范目的与适用范围

本文档定义 docker-compose-stacks 项目中 Installer 对运行时目录与权限的唯一合法行为边界。

本规范的目标是：

| 在不引入人工权限修复、不破坏 Stack 自治的前提下，  |
| 确保所有 Stack 在真实环境中可稳定启动。  |

本规范对所有未来 Installer 修改具有约束力。

## 二、运行时目录模型
### 2.1 标准运行路径

所有 Stack 必须部署在以下路径下运行：
```swift
/opt/docker/<stack-id>/
```

其中：

- <stack-id> 对应 stacks/ 目录下的 Stack 路径

- 示例：
```bash
stacks/nginx-proxy-manager
→ /opt/docker/nginx-proxy-manager
```

严禁在仓库目录中直接运行 Stack。

## 三、Installer 的职责边界
### 3.1 Installer 必须做的事

Installer 只负责以下事项：

- 创建 Stack 对应的运行时目录

- 保证该目录 对容器进程可写

- 不依赖、不推断容器内部的用户模型

### 3.2 Installer 明确禁止的行为

Installer 不得：

- 假设容器使用特定 UID / GID

- 解析或猜测 docker-compose.yml 中的用户配置

- 基于固定 UID/GID 执行 chown

- 侵入 Stack 的运行期行为或业务语义

## 四、冻结的权限规则（核心条款）
### 4.1 强制性权限保证

对于任意 Stack，其运行时目录：
```arduino
/opt/docker/<stack-id>
```

Installer 必须保证：

该目录对“非 root UID 的容器进程”可写。

### 4.2 允许的权限模式

以下权限模式被正式批准：

- 推荐（安全与兼容性平衡）：
```bash
chmod 775 /opt/docker/<stack-id>
```

- 允许（最高兼容性）：
```bash
chmod 777 /opt/docker/<stack-id>
```

具体采用哪一种属于 Installer 的实现细节，但**“可写性”是不可妥协的要求**。

## 五、明确禁止的权限操作

Installer 在任何情况下都不得执行：
```bash
chown -R 1000:1000 /opt/docker/<stack-id>
```

或任何基于固定 UID / GID 假设的所有权修改。

原因：

- 容器用户模型由镜像作者定义

- 不同镜像的 UID/GID 差异巨大

- 硬编码 chown 会在长期演进中引入隐蔽且不可预测的故障

## 六、Installer 与 Stack 的职责划分
### Installer 的职责

- 创建 /opt/docker/<stack-id>

- 保证目录对容器可写

- 不关心 volume 内部的子目录结构

### Stack 的职责

- 在 docker-compose.yml 中使用相对路径挂载

- 由 Docker 或容器自身创建 data/、logs/ 等子目录

- 若对用户或权限有特殊要求，必须在 Stack 文档中明确说明

Stack 不得依赖 Installer 进行所有权修复。

## 七、设计说明（为什么这样规定）
### 7.1 为什么 chmod 755 不可接受

- 755 仅允许 owner 写

- Installer 创建目录时 owner 通常为 root

- 绝大多数容器以非 root 用户运行

- 该组合在真实部署中 必然失败

此结论已在多个真实 Stack（如 Nginx Proxy Manager）中得到验证。

### 7.2 为什么允许 775 / 777

- /opt/docker 的语义是 容器运行沙箱

- 安全边界依赖：

    - 目录路径隔离

    - Docker 容器隔离

- 而非宿主机 Unix 用户模型

在该语义下，“可写”是功能前提，而非安全反模式。

## 八、规范变更策略

本规范为冻结规范。

任何修改必须：

- 显式提出

- 给出充分理由

- 证明不违反以下原则：

    - Installer-first

    - Stack 自治

    - 长期向后兼容

## 九、规范性总结（一句话）

| Installer 的责任是让运行目录“任何容器都能写”，  
| 而不是决定“哪个用户来写”。  