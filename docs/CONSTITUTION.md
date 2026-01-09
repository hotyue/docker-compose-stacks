# Docker Compose Stacks  
## 项目宪法（Constitution v1.0）

> 本文档定义本项目的**长期演进边界、架构原则与协作规则**。  
> 所有重大设计变更，均不得违反本宪法。

---

## 第一章：项目定位（Project Identity）

### 第一条｜项目性质

本项目是一个 **Installer 驱动的 Docker Compose 应用栈仓库**，用于部署和管理自托管服务。

- 本项目不是 Docker Compose 模板合集
- 本项目不是 PaaS / 控制面 / 平台
- 本项目不引入 Kubernetes、Ansible 等重型系统

---

### 第二条｜核心目标

本项目的长期目标是：

> 在保持 Docker Compose 简单性的前提下，  
> 提供一个 **可扩展、可维护、可规模化演进** 的自托管部署体系。

---

## 第二章：架构原则（Architecture Principles）

### 第三条｜Installer 优先原则（Installer-First）

- Installer 是项目的**唯一统一入口**
- Installer 负责：
  - Stack 发现（基于 `stack.meta`）
  - 依赖调度（如共享 Docker network）
  - 状态记录（`.installed`）
- Installer **不理解任何具体应用实现**

---

### 第四条｜Stack 自治原则（Stack Autonomy）

每个 Stack 必须：

- 能够独立运行
- 不依赖 Installer 的特殊逻辑
- 不假设安装顺序
- 不修改自身以适配其它 Stack

Installer 负责调度，  
但 **不侵入 Stack 内部实现**。

---

### 第五条｜Meta 驱动原则（Meta-Driven）

- Stack 的可发现性完全来自 `stack.meta`
- Installer、README 索引、CI 只依赖 meta
- 禁止在 Installer 中硬编码应用信息

---

## 第三章：命名与版本（Naming & Versioning）

### 第六条｜Stack ID 稳定性

- `stacks/<stack-id>/` 是 Stack 的唯一稳定 ID
- Stack ID：
  - 全小写
  - kebab-case
  - 不得包含版本号
- Stack ID 一经创建，不得随版本变更而修改

---

### 第七条｜版本外置原则

- 版本信息只能存在于：
  - Docker image tag
  - `.env` / `.env.example`
  - README 说明
- 禁止通过目录名或分类区分版本

---

### 第八条｜实现区分原则

- 同一软件的不同版本：**一个 Stack**
- 不同实现（如 mysql / mariadb）：**不同 Stack**

---

## 第四章：目录与分类（Structure & Category）

### 第九条｜结构与视图分离

- 目录结构是稳定结构
- 分类（CATEGORY）是视图
- 禁止通过目录层级表达分类

---

### 第十条｜分类冻结原则

- CATEGORY 取值来自受控集合
- 新分类需充分理由
- 分类调整视为架构级变更

---

## 第五章：文档与自动化（Docs & Automation）

### 第十一条｜文档生成优先

- README 中的 Stacks 列表为生成物
- 禁止手写维护 Stack 清单
- 文档必须可被脚本重建

---

### 第十二条｜CI 作为强制力

- CI 用于校验规范一致性
- CI 失败即视为不合规
- 人工 review 不替代自动校验

---

## 第六章：协作与演进（Governance）

### 第十三条｜最小承诺原则

- 不承诺未实现能力
- 不提前引入复杂系统
- 不为“可能的未来”牺牲当前清晰度

---

### 第十四条｜向后兼容优先

- 破坏性变更需明确标识
- 重大结构调整需迁移方案
- Installer 行为变化需谨慎

---

### 第十五条｜宪法优先级

- 本宪法高于 README 与具体实现
- 如需修改宪法，必须通过 PR 讨论
- 修宪需明确动机与替代方案

---

## 附则

### 生效说明

- 本宪法自发布之日起生效
- 当前版本：**Constitution v1.0**
- 后续修订需递增版本号

---

> 本项目的复杂性，来自规模，而不是设计。  
> 本宪法的目标，是在规模到来之前，保持清晰。
