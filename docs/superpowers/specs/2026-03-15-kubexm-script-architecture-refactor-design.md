# KubeXM Script 架构重构设计

日期：2026-03-15

## 1. 目标与范围

本次重构目标是在 **Bash 脚本体系**内完成架构重构，建立清晰分层与职责边界，构建可组合、可观测、可维护的执行体系。

**核心目标**（用户明确要求全覆盖）：
- 清晰分层与职责解耦
- 执行链路可观测性
- 原子性/幂等性保障
- 配置驱动与可组合性
- 保持现有功能不回归（基础流程可跑）
- 改造成本最低（渐进式迁移）

**允许破坏性变更**：CLI 命令/参数、目录结构、旧脚本路径允许变更。

## 2. 分层架构与职责边界

### 2.1 层级结构

```
kubexm/
├── bin/
│   └── kubexm                 # CLI 入口，仅解析与路由
├── internal/
│   ├── cmd/                   # CLI 子命令（解析参数 -> Pipeline）
│   ├── pipeline/              # 全流程编排（跨主机）
│   ├── module/                # 业务模块（组合 Task）
│   ├── task/                  # 任务集合（组合 Step）
│   ├── step/                  # 原子步骤库（幂等）
│   ├── runner/                # 执行驱动（生命周期、重试、回滚）
│   └── connector/             # SSH/本地连接封装
├── conf/                      # 现有配置中心（不变）
├── lib/                       # 兼容层 + 共享基础库（逐步收敛）
└── scripts/                   # 过渡期保留（旧脚本适配层）
```

### 2.2 边界约束

- **Step 不直接调用 Connector**，必须通过 Runner
- **Task 仅由 Step 组装**，不含执行细节
- **Module 仅由 Task 组装**
- **Pipeline 仅编排 Module**
- Runner 负责 Step 的生命周期（执行/重试/回滚/日志）
- Connector 只处理连接与命令下发

## 3. 执行流与接口契约

### 3.1 执行流（自顶向下）

**CLI → Pipeline → Module → Task → Step → Runner → Connector**

- **CLI (bin/kubexm)**：仅解析参数、路由
- **Pipeline**：读取配置、初始化 Context、按序触发 Module
- **Module**：按业务域组织 Task
- **Task**：组合 Step 并控制顺序/策略
- **Step**：原子操作单元（幂等）
- **Runner**：执行驱动，统一重试/回滚/日志
- **Connector**：SSH/Local 执行与传输

### 3.2 接口草案（Bash 伪签名）

```
# Context
context::init
context::get <key>
context::set <key> <value>
context::with <scope> <fn>
context::cancel

# Pipeline
pipeline::run <pipeline_name> <context>

# Module
module::run <module_name> <context>

# Task
task::run <task_name> <context>

# Step
step::<name>::targets <context>     # 返回目标主机列表或角色选择
step::<name>::check <context>
step::<name>::run <context>
step::<name>::rollback <context>     # optional

# Runner
runner::exec <step_name> <context> <target_host>

# Connector
connector::exec <host> <command>
connector::copy <src> <dest> <host>
```

### 3.3 原子性/幂等性约束

- `check` 必须无副作用、可重复执行
- `run` 必须可重复执行且不破坏状态
- Runner 执行链路：`check -> run -> check`，失败触发回滚

## 4. 支撑体系（基础设施层）

**Logger**
- Debug/Info/Warn/Error
- JSON + 彩色 Console
- 自动携带 `task_id` / `step_name` / `host` / `run_id`
- JSON 输出在 Bash 内完成转义（至少转义 `\`、`"`、控制字符）

**Context**
- Pipeline/Module/Task/Step 之间传递
- 支持取消信号
- Bash-only：使用关联数组 + 临时文件（`run_id` 目录）持久化

**Parser**
- 解析 `conf/{cluster}/config.yaml` 与 `host.yaml`
- 解析 SSH 凭据与目标主机
- Bash-only：复用现有解析逻辑与字段映射，不引入新配置文件/字段

**Conf**
- 多源合并：CLI > ENV > YAML > defaults
- 深度合并策略：以键路径为单位覆盖（优先级高的值覆盖低优先级）

**Utils**
- 字符串、文件 I/O、网络检测、时间格式化

**Errors**
- RecoverableError / FatalError
- Bash 约定：退出码区间区分（例如 10–19 可恢复，20–29 致命）

**Containers**
- OS Dockerfile 离线依赖构建

**Templates**
- 模板中心

**Cache**
- 缓存中心

## 5. 配置中心化与参数传递

- **配置唯一入口**：`conf/{cluster}/config.yaml + host.yaml`
- **字段不变**：不新增配置字段
- **Parser 统一解析**，生成结构化 Context
- **逐级传参**：Pipeline → Module → Task → Step
- Step 仅使用参数，不修改全局配置

## 6. 迁移策略（分层主干 + 渐进替换）

**阶段 1：搭骨架**
- 新增 internal/* 分层目录
- 保留 scripts/ 与 lib/ 旧逻辑

**阶段 2：适配层**
- 将旧 phase 脚本包装为 Step
- Task 组合替代旧 phase 顺序
- Parser 统一产出 Context

**阶段 3：入口切换**
- CLI → Pipeline
- 旧入口转发或删除（允许破坏性）

**阶段 4：清理与收敛**
- scripts/phase 逐步裁撤
- lib/ 重复逻辑迁移到 internal/
- 重构完成后清理旧目录（由实现阶段决定具体清单）

## 7. 错误处理、日志与验收标准

**错误处理**
- Runner 区分可恢复与致命错误
- 可恢复错误触发重试，致命错误终止 Pipeline
- 退出码区间：10–19 可恢复，20–29 致命

**日志**
- 统一 Logger API
- JSON + Console
- 自动携带 `task_id` / `step_name` / `host` / `run_id` / `pipeline_name`

**Context**
- 支持取消信号与链路传递

**验收标准**
- CLI 全量映射到 Pipeline
- 所有动作由 Step 执行，Step 不直接调用 Connector
- 日志可追踪到 step_name/run_id
- Parser 可稳定解析 conf/{cluster}/config.yaml + host.yaml 到 Context
- conf 目录配置保持不变即可运行
- 迁移后核心流程可跑
