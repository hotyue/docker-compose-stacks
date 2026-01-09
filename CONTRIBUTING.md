# 贡献指南（Contributing Guide）

感谢你对本项目的兴趣与贡献意愿 🙏  
在提交 Issue 或 Pull Request 前，请先阅读本指南。

---

## 一、项目定位说明（请先阅读）

本仓库是一个 **基于 Installer 的 Docker Compose 应用仓库**，  
核心目标是：

- 提供结构化、可扩展的自托管部署方案
- 所有应用栈可被统一 Installer 调度
- 避免隐式依赖与“只能手动操作”的流程

因此，并非所有 Docker Compose 示例都适合加入本仓库。

---

## 二、贡献内容类型

我们欢迎以下类型的贡献：

### ✅ 新增应用栈（Stack）

- 常见、自托管、有长期价值的服务
- 结构清晰、无侵入式魔改
- 能独立运行，也能被 Installer 调度

### ✅ 改进 Installer

- 交互体验优化
- 稳定性与健壮性提升
- 向后兼容的功能增强

### ✅ 文档改进

- README / docs 补充
- 部署说明优化
- 常见问题整理

---

## 三、新增 Stack 的基本要求（重要）

每个新增 Stack **必须满足以下条件**：

### 1️⃣ 目录结构

```text
stacks/<stack-name>/
├── docker-compose.yml
├── README.md
└── stack.meta
```

如存在多角色（server / agent），可使用子目录拆分。

---

### 2️⃣ stack.meta（必需）

必须包含以下字段：

```ini
NAME="应用名称"
CATEGORY="分类"
DESCRIPTION="一句话说明"
```

如依赖共享资源（如 proxy）：

```ini
REQUIRES_NETWORK="proxy"
```

### 3️⃣ Docker Compose 规范

- 不使用绝对路径挂载

- 数据目录统一使用 ./data

- 共享网络使用 external: true

- 不假设安装顺序

- 不强制依赖手工步骤

### 4️⃣ Installer 兼容性

- Stack 必须能被 Installer 无特判启动

- 不要求用户在启动前修改 compose 文件

- .env.example（如存在）应可直接复制使用

---

## 四、Pull Request 规范

一个 PR 只做一件事

 1️⃣ 提交前请自测：

- docker compose up -d

- ./install.sh

 2️⃣ PR 描述中说明：

- 变更内容

- 是否影响 Installer

- 是否向后兼容

---

## 五、Issue 使用说明

 1️⃣ Bug 请提供：

- 运行环境

- 执行命令

- 完整错误输出

 2️⃣ 新功能建议请说明：

- 使用场景

- 是否影响现有结构

---

## 六、代码风格与语言

- 文档默认使用 中文

- 注释与说明清晰优先于“炫技”

- 保持脚本可读性（bash > 复杂技巧）

感谢你的贡献 ❤️
每一个规范的 PR，都会让这个项目更稳、更可维护。

