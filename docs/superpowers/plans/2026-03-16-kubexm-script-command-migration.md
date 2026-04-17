# KubeXM 命令链迁移 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 kubexm 全量命令链迁移到 Pipeline/Module/Task/Step 执行路径，保持 conf/{cluster}/config.yaml + host.yaml 为唯一配置入口，强制 SSH-only，满足在线/离线流程与离线工具要求。

**Architecture:** 为每条命令链创建对应 pipeline/module/task 与 step 适配器，step 只封装旧 phase 脚本调用；runner 统一执行 check→run→check；connector 强制 SSH-only 并屏蔽 localhost/127。迁移完成后再清理旧目录。

**Tech Stack:** Bash, 现有 internal/step/legacy/phases, internal pipeline/module/task/step/runner/connector, tests/run-tests.sh

---

## File Structure (责任划分)
- Modify: `bin/kubexm` — CLI 解析与路由到 pipeline
- Create: `internal/pipeline/*` — 每条命令链对应 pipeline
- Create: `internal/module/*` — 每条命令链对应 module
- Create: `internal/task/*` — 每条命令链对应 task
- Create: `internal/step/steps/*` — 旧 phase 适配为 step
- Modify: `internal/step/registry.sh` — 注册新 steps
- Modify: `internal/runner/runner.sh` — 保持统一执行策略
- Modify: `internal/connector/connector.sh` — SSH-only 强制
- Tests: `tests/cases/*` — 新增/扩展命令链的 pipeline/step 覆盖

---

## Chunk 1: CLI 命令链清单与路由骨架

### Task 1: 归档 CLI 命令链并映射到 pipeline 路由

**Files:**
- Modify: `bin/kubexm` (主 dispatch 区域)
- Test: `tests/cases/cli_pipeline_dispatch.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/cli_pipeline_dispatch.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

output="$(KUBEXM_ROOT="${ROOT}" bash ${ROOT}/bin/kubexm help 2>/dev/null || true)"
[[ "${output}" == *"Usage"* ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/cli_pipeline_dispatch.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Update `bin/kubexm` dispatch to route the following commands to pipelines (stub ok for now):
- `download`
- `create cluster`
- `create registry`
- `delete cluster`
- `delete registry`
- `push images`
- `scale cluster`
- `upgrade cluster`
- `upgrade etcd`
- `renew kubernetes-ca`
- `renew etcd-ca`
- `renew kubernetes-certs`
- `renew etcd-certs`
- `create manifests`
- `create iso`

Example skeleton mapping:

```bash
case "$1" in
  download) pipeline::download "${ctx}" ;;
  create) case "$2" in
    cluster) pipeline::create_cluster "${ctx}" ;;
    registry) pipeline::create_registry "${ctx}" ;;
  esac ;;
  delete) case "$2" in
    cluster) pipeline::delete_cluster "${ctx}" ;;
    registry) pipeline::delete_registry "${ctx}" ;;
  esac ;;
  push) case "$2" in
    images) pipeline::push_images "${ctx}" ;;
  esac ;;
  scale) case "$2" in
    cluster) pipeline::scale_cluster "${ctx}" ;;
  esac ;;
  upgrade) case "$2" in
    cluster) pipeline::upgrade_cluster "${ctx}" ;;
    etcd) pipeline::upgrade_etcd "${ctx}" ;;
  esac ;;
  renew) case "$2" in
    kubernetes-ca) pipeline::renew_kubernetes_ca "${ctx}" ;;
    etcd-ca) pipeline::renew_etcd_ca "${ctx}" ;;
    kubernetes-certs) pipeline::renew_kubernetes_certs "${ctx}" ;;
    etcd-certs) pipeline::renew_etcd_certs "${ctx}" ;;
  esac ;;
  *) show_help ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/cli_pipeline_dispatch.sh`
Expected: PASS

- [ ] **Step 5: Commit**

Skip (no git).

---

## Chunk 2: Step 适配器与 Task/Module/Pipeline 搭建

### Task 2: 为 download 命令链创建 pipeline/module/task/step

**Files:**
- Create: `internal/pipeline/download.sh`
- Create: `internal/module/download.sh`
- Create: `internal/task/download.sh`
- Create: `internal/step/steps/download_resources.sh`
- Modify: `internal/step/registry.sh`
- Test: `tests/cases/pipeline_download.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/pipeline_download.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/internal/pipeline/download.sh"

KUBEXM_DRY_RUN=true
pipeline::download "ctx"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/pipeline_download.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

- `pipeline::download` 调用 `module::download_prepare`。
- `module::download_prepare` 调用 `task::download_resources`。
- `task::download_resources` 注册并执行 step：`download.resources`。
- `step::download.resources::run` 调用旧脚本：`internal/step/legacy/phases/resources/download.sh` 中的函数（只封装）。
- `step::download.resources::targets` 返回空或中心节点（下载不需要 host.yaml 校验）。

Skeleton step:

```bash
step::download.resources::check() { return 1; }
step::download.resources::run() { source "${KUBEXM_ROOT}/internal/step/legacy/phases/resources/download.sh"; phases::download_resources; }
step::download.resources::targets() { echo ""; }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/pipeline_download.sh`
Expected: PASS

- [ ] **Step 5: Commit**

Skip (no git).

---

### Task 3: 为 create cluster 命令链创建 pipeline/module/task/step

**Files:**
- Create: `internal/pipeline/create_cluster.sh`
- Create: `internal/module/create_cluster.sh`
- Create: `internal/task/create_cluster.sh`
- Create: `internal/step/steps/phase_create_cluster.sh`
- Modify: `internal/step/registry.sh`
- Test: `tests/cases/pipeline_create_cluster.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/pipeline_create_cluster.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/internal/pipeline/create_cluster.sh"

KUBEXM_DRY_RUN=true
pipeline::create_cluster "ctx"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/pipeline_create_cluster.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

- `pipeline::create_cluster` 在线模式先调用 `pipeline::download`，再调用 `module::create_cluster_prepare`。
- `module::create_cluster_prepare` 调用 `task::create_cluster`。
- `task::create_cluster` 注册并执行 step：`phase.create_cluster`。
- `step::phase.create_cluster::run` 调用旧脚本：`internal/step/legacy/phases/cluster/create-cluster.sh` 的 `phases::create_cluster`。

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/pipeline_create_cluster.sh`
Expected: PASS

- [ ] **Step 5: Commit**

Skip (no git).

---

### Task 4: create registry / delete registry / push images / delete cluster / scale / upgrade / renew 迁移

**Files:**
- Create: `internal/pipeline/*.sh` (create_registry, delete_registry, push_images, delete_cluster, scale_cluster, upgrade_cluster, upgrade_etcd, renew_*)
- Create: `internal/module/*.sh`
- Create: `internal/task/*.sh`
- Create: `internal/step/steps/*.sh` (phase adapters)
- Modify: `internal/step/registry.sh`
- Test: `tests/cases/pipeline_*` (dry-run minimal)

- [ ] **Step 1: Write the failing tests**

Add minimal dry-run pipeline tests for each命令链：

```bash
KUBEXM_DRY_RUN=true
pipeline::delete_cluster "ctx"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/cases/pipeline_delete_cluster.sh` (repeat per chain)
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

For each chain:
- pipeline → module → task
- task registers steps
- steps call existing `internal/step/legacy/phases/**` functions

Examples:
- delete cluster → `internal/step/legacy/phases/cluster/delete-cluster.sh` `phases::delete_cluster`
- scale cluster → `internal/step/legacy/phases/cluster/scale-cluster.sh` `phases::scale_cluster`
- upgrade cluster → `internal/step/legacy/phases/cluster/upgrade-cluster.sh` `phases::upgrade_cluster`
- upgrade etcd → `internal/step/legacy/phases/cluster/upgrade-etcd.sh` `phases::upgrade_etcd`
- registry create/delete/push → `internal/step/legacy/phases/registry/*.sh`
- renew certs → `internal/step/legacy/phases/certificates/*.sh`

- [ ] **Step 4: Run tests to verify they pass**

Run each pipeline test.
Expected: PASS

- [ ] **Step 5: Commit**

Skip (no git).

---

## Chunk 3: 离线工具检查与 SSH-only 统一约束

### Task 5: 强化工具检查与 SSH-only

**Files:**
- Modify: `internal/step/steps/check_tools.sh`
- Modify: `internal/connector/connector.sh`
- Test: `tests/cases/runner_connector.sh`

- [ ] **Step 1: Write the failing test**

Extend `tests/cases/runner_connector.sh` to ensure empty host rejected and localhost rejected.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/cases/runner_connector.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

- connector::exec/copy/copy_from reject empty/localhost/127
- check_tools step ensures jq/yq/xmjq/xmyq and phase-required tools present

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/cases/runner_connector.sh`
Expected: PASS

- [ ] **Step 5: Commit**

Skip (no git).

---

## Chunk 4: 旧目录清理（迁移完成后）

### Task 6: 删除旧目录

**Files:**
- Remove: legacy directories verified unused
- Test: `tests/run-tests.sh unit`

- [ ] **Step 1: Identify unused legacy paths**

Locate `scripts/` & `lib/` paths that are no longer referenced by new pipelines.

- [ ] **Step 2: Remove unused directories**

Delete only confirmed unused paths.

- [ ] **Step 3: Run tests to verify**

Run: `bash tests/run-tests.sh unit`
Expected: PASS

- [ ] **Step 4: Commit**

Skip (no git).

---

Plan complete and saved to `docs/superpowers/plans/2026-03-16-kubexm-script-command-migration.md`. Ready to execute?
