# KubeXM Script 命令链迁移设计

日期：2026-03-16

## 1. 目标与范围
本阶段目标是在现有 Bash 体系内，把所有命令链迁移到新的 Pipeline/Module/Task/Step 结构，保持配置中心不变并强制 SSH-only 执行。

**范围（全量迁移）：**
- download
- create cluster
- create registry
- delete cluster
- delete registry
- push images
- scale cluster
- upgrade cluster
- upgrade etcd
- renew kubernetes-ca
- renew etcd-ca
- renew kubernetes-certs
- renew etcd-certs

**约束（必须满足）：**
- 配置入口仅限 `conf/{cluster}/config.yaml + host.yaml`，不新增字段/文件。
- 仅 SSH 执行：禁止 localhost/127.0.0.1；若无显式主机列表，自动解析主机主 IP 并 SSH。
- 在线模式：`create cluster` 触发自动 `download`；离线模式：`download` 不校验 host.yaml。
- 工具离线可用：jq/yq/xmjq/xmyq 及所有脚本所需工具须可离线。

## 2. 迁移顺序
统一按以下顺序迁移，并在每条命令链完成后进行最小验证：
1. download
2. create cluster
3. create registry
4. delete cluster
5. delete registry
6. push images
7. scale cluster
8. upgrade cluster
9. upgrade etcd
10. renew kubernetes-ca
11. renew etcd-ca
12. renew kubernetes-certs
13. renew etcd-certs

## 3. 分层结构与职责
- **CLI（bin/kubexm）**：参数解析与路由，调用 Pipeline。
- **Pipeline**：流程编排（跨主机），只调用 Module。
- **Module**：业务域组合，只调用 Task。
- **Task**：步骤编排，只调用 Step。
- **Step**：原子操作，提供 `targets/check/run/rollback`，不直接调用 Connector。
- **Runner**：统一执行策略（check→run→check），处理中断/日志。
- **Connector**：SSH/传输封装（禁止 localhost/127）。

## 4. 适配策略
- 保留 `internal/step/legacy/phases/**` 作为过渡层，不直接调用旧入口。
- 为每个旧 phase 编写 Step 适配器（只封装调用，不改逻辑），实现 targets/check/run/rollback。
- 由 Task 组合 Step，Module 组合 Task，Pipeline 组合 Module。
- 同名命令链仅保留新入口，旧入口可被移除。

## 5. 在线/离线与工具检查
- download 入口不校验 host.yaml，允许离线准备包。
- create cluster 在在线模式下自动触发 download。
- 在 Task/Step 层明确工具检查列表（jq/yq/xmjq/xmyq 等），未满足则提前失败。

## 6. 验收标准
- 六条命令链全部通过新的 Pipeline/Module/Task/Step 路径执行。
- 所有 Step 不直接调用 Connector。
- SSH-only 规则全局生效（禁止 localhost/127）。
- 在线/离线流程符合约束。
- 迁移完成后清理旧目录与冗余入口。
