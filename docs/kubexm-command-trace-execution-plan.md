# KubeXM 命令追踪报告 —— 可执行计划

> 目的：将现有《命令追踪报告》从“静态汇总”提升为“可复核、可执行、可验收”的最终报告。
> 输入：`docs/kubexm-command-trace-report.md` + `docs/superpowers/specs/2026-03-11-kubexm-command-trace-design.md`
> 输出：更新后的 `docs/kubexm-command-trace-report.md`（全量覆盖、证据齐全）

---

## 0. 执行前准备

- [ ] 打开并通读：
  - `docs/kubexm-command-trace-report.md`
  - `docs/superpowers/specs/2026-03-11-kubexm-command-trace-design.md`
- [ ] 确认范围：只做静态分析，不运行脚本、不改业务代码。
- [ ] 证据格式统一：`file:line` 或报告章节号（如 §3.3）。

---

## 1. 补全 2.4 逐命令选项索引

> 目标：确保 2.4 中每个命令的选项与解析分支完全对齐，并附 `file:line` 证据。

- [ ] 从 `bin/kubexm` 与任务步骤中提取：
  - `show_*_help` 中的选项列表
  - `internal/task/**` 与 `internal/step/**` 中的实际解析分支
- [ ] 逐命令填充 2.4：
  - download / create cluster / create registry / create manifests / create iso / delete cluster / delete registry / push images / scale cluster / upgrade cluster / upgrade etcd / renew certs
- [ ] 为每个选项添加证据位置（help + 解析分支）

完成标准：
- [ ] 2.4 所有命令都有选项清单
- [ ] 每条选项有至少一个 `file:line` 证据

---

## 2. 完整化命令分章（§3.x）

> 目标：每条命令章节满足 §10.1 模板，包含完整调用链、多分支最深执行点、参数传播点。

对每个命令执行：
- [ ] 核对入口位置（`bin/kubexm`）
- [ ] 补齐调用链（source → phase → lib → 外部命令）
- [ ] 补齐“最深执行点”
  - 如果存在多分支（如 kubeadm/kubexm、online/offline、local/remote chart），分别列出
- [ ] 标注参数传播点（CLI → ENV → conf → defaults → derived/runtime）

完成标准：
- [ ] §3.1–§3.18 全部满足模板
- [ ] 多分支最深执行点均明确
- [ ] 参数传播点有证据位置

---

## 3. 补全参数来源矩阵（§4）

> 目标：覆盖所有模块参数（含运行时变量），并显式列出 DEFAULT_* 或字面默认值。

- [ ] 扩展矩阵到以下模块：
  - `lib/modules/**`
  - `lib/tasks/**`
  - `lib/deployment/**`
  - `lib/addons/**`
  - `internal/step/legacy/phases/**`
- [ ] 每个参数补齐：
  - 来源（CLI/ENV/conf/defaults/derived/runtime）
  - 默认值（DEFAULT_* 或字面值）
  - 约束 / 场景 / 触发条件
  - `file:line` 证据
- [ ] 与 §3 章节建立引用（可用“见 §3.x”或双向链接）

完成标准：
- [ ] 参数矩阵覆盖所有可见参数与运行时变量
- [ ] 每条参数有默认值与证据

---

## 4. 风险与可靠性要点补证据

> 目标：每条命令的“风险与可靠性要点”都有触发条件与证据。

- [ ] 为每条风险项补充：
  - 触发条件
  - 证据位置（file:line / §3.x）
- [ ] 确保风险覆盖 spec §2.3 九类维度

完成标准：
- [ ] 所有命令风险项具备证据

---

## 5. 验证清单执行化（§12/§13）

> 目标：让清单可逐项打勾并附证据。

- [ ] 在 §12 清单每一条后补“证据位置模板”
- [ ] 在 §13 样例审计表中填入示例证据（至少 1–2 条）

完成标准：
- [ ] §12/§13 每项都可落地执行

---

## 6. 最终一致性审计

- [ ] 对照 spec §12–§13 逐项核验
- [ ] 确认报告已满足：
  - 全量命令/参数覆盖
  - 最深执行点可追溯
  - 参数矩阵完整
  - 风险清单完整

产出：
- [ ] 在报告尾部增加“完成记录段落”
  - 执行日期
  - 覆盖统计
  - 未覆盖项（如有）

---

## 验收标准（最终）

- [ ] `docs/kubexm-command-trace-report.md` 满足 spec §13 的覆盖与可回溯性要求
- [ ] `file:line` 证据完整
- [ ] 多分支最深执行点全部列出
- [ ] 参数矩阵完整、默认值明确

---

## 附：证据引用格式规范

- 代码位置：`path/to/file.sh:123-130`
- 报告章节：`§3.3` / `§4.2`
- 分支说明：`(条件：kubernetes_type=kubexm)`
