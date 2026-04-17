# KubeXM Script Architecture Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the kubexm-script Bash codebase into layered Pipeline/Module/Task/Step/Runner/Connector architecture while preserving conf/{cluster}/config.yaml + host.yaml as the sole configuration entry, enforcing SSH-only execution (no localhost/127.0.0.1), and ensuring all required tools/components (jq/yq etc.) are available offline.

**Architecture:** Build a new internal/ hierarchy with Bash-only support systems (context, logger, parser, errors), adapt existing scripts into Steps, and switch CLI routing to Pipelines. Migrate incrementally and remove legacy directories once the new flow is verified. Enforce SSH execution via real host IP (even for local-only runs) and add offline packaging for jq/yq and all required runtime tools.

**Tech Stack:** Bash, existing shell libs, current conf/ YAML, tests/run-tests.sh

---

> **Note:** This repository uses git; keep commit steps. Do not skip commits unless requested by the user.

---

## Chunk 1: Foundations (Directories, Context, Logger, Parser, Errors)

### Task 1: Create internal/ skeleton and loader

**Files:**
- Create: `internal/loader.sh`
- Create: `internal/context/context.sh`
- Create: `internal/logger/logger.sh`
- Create: `internal/errors/errors.sh`
- Create: `internal/parser/parser.sh`
- Modify: `bin/kubexm:1-60` (source loader)

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/architecture_layout.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for path in \
  internal/loader.sh \
  internal/context/context.sh \
  internal/logger/logger.sh \
  internal/errors/errors.sh \
  internal/parser/parser.sh; do
  [[ -f "${ROOT}/${path}" ]] || { echo "missing ${path}"; exit 1; }
done
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/architecture_layout.sh`
Expected: FAIL with “missing …”

- [ ] **Step 3: Write minimal implementation**

```bash
# internal/loader.sh
#!/usr/bin/env bash
set -euo pipefail
KUBEXM_INTERNAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
source "${KUBEXM_INTERNAL_ROOT}/context/context.sh"
source "${KUBEXM_INTERNAL_ROOT}/logger/logger.sh"
source "${KUBEXM_INTERNAL_ROOT}/errors/errors.sh"
source "${KUBEXM_INTERNAL_ROOT}/parser/parser.sh"
```

```bash
# internal/context/context.sh
#!/usr/bin/env bash
set -euo pipefail
context::init() { :; }
context::get() { :; }
context::set() { :; }
context::with() { :; }
context::cancel() { :; }
```

```bash
# internal/logger/logger.sh
#!/usr/bin/env bash
set -euo pipefail
logger::debug() { :; }
logger::info() { :; }
logger::warn() { :; }
logger::error() { :; }
```

```bash
# internal/errors/errors.sh
#!/usr/bin/env bash
set -euo pipefail
ERROR_RECOVERABLE_MIN=10
ERROR_RECOVERABLE_MAX=19
ERROR_FATAL_MIN=20
ERROR_FATAL_MAX=29
```

```bash
# internal/parser/parser.sh
#!/usr/bin/env bash
set -euo pipefail
parser::load_config() { :; }
parser::load_hosts() { :; }
```

Update `bin/kubexm` to export `KUBEXM_ROOT` first, then source `internal/loader.sh` near the top. Note: any tests that source internal modules directly must export `KUBEXM_ROOT` before invoking parser/connector functions.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/architecture_layout.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/loader.sh internal/context/context.sh internal/logger/logger.sh internal/errors/errors.sh internal/parser/parser.sh bin/kubexm tests/cases/architecture_layout.sh

git commit -m "feat: add internal skeleton and loader"
```

---

### Task 2: Implement Context storage (Bash-only)

**Files:**
- Modify: `internal/context/context.sh`
- Test: `tests/cases/context_storage.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/context_storage.sh
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/internal/context/context.sh"

context::init
context::set "foo" "bar"
[[ "$(context::get "foo")" == "bar" ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/context_storage.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```bash
# internal/context/context.sh
#!/usr/bin/env bash
set -euo pipefail

declare -A KUBEXM_CONTEXT=()
KUBEXM_CONTEXT_DIR=""

context::_ensure_dir() {
  [[ -n "${KUBEXM_CONTEXT_DIR}" ]] || KUBEXM_CONTEXT_DIR="/tmp/kubexm-context-${KUBEXM_RUN_ID:-default}"
  mkdir -p "${KUBEXM_CONTEXT_DIR}"
}

context::init() {
  KUBEXM_RUN_ID="${KUBEXM_RUN_ID:-$(date +%s%N)}"
  KUBEXM_CONTEXT_DIR="/tmp/kubexm-context-${KUBEXM_RUN_ID}"
  mkdir -p "${KUBEXM_CONTEXT_DIR}"
}

context::set() {
  local key="$1" value="$2"
  context::_ensure_dir
  KUBEXM_CONTEXT["${key}"]="${value}"
  printf '%s' "${value}" > "${KUBEXM_CONTEXT_DIR}/${key}"
}

context::get() {
  local key="$1"
  if [[ -n "${KUBEXM_CONTEXT["${key}"]+x}" ]]; then
    printf '%s' "${KUBEXM_CONTEXT["${key}"]}"
    return 0
  fi
  context::_ensure_dir
  if [[ -f "${KUBEXM_CONTEXT_DIR}/${key}" ]]; then
    cat "${KUBEXM_CONTEXT_DIR}/${key}"
    return 0
  fi
  return 1
}

context::with() {
  local scope="$1" fn="$2"
  if [[ "$(context::get "cancelled")" == "true" ]]; then
    return 1
  fi
  "${fn}" "${scope}"
}

context::cancel() {
  context::set "cancelled" "true"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/context_storage.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/context/context.sh tests/cases/context_storage.sh

git commit -m "feat: add context storage"
```

---

### Task 3: Implement Logger JSON + console output (Bash-only)

**Files:**
- Modify: `internal/logger/logger.sh`
- Test: `tests/cases/logger_output.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/logger_output.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/internal/logger/logger.sh"

stdout_file="/tmp/kubexm-log-stdout"
stderr_file="/tmp/kubexm-log-stderr"

KUBEXM_TASK_ID="t-1" KUBEXM_PIPELINE_NAME="p-1" KUBEXM_RUN_ID="r-1" KUBEXM_STEP_NAME="s-1" KUBEXM_HOST="h-1" \
  logger::info "test message" >"${stdout_file}" 2>"${stderr_file}"

# JSON stdout contains required keys
jq -e '.task_id=="t-1" and .pipeline_name=="p-1" and .run_id=="r-1" and .step_name=="s-1" and .host=="h-1" and .msg=="test message"' "${stdout_file}" >/dev/null

# stderr contains human-readable line
grep -q "\[INFO\] test message" "${stderr_file}"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/logger_output.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```bash
# internal/logger/logger.sh
#!/usr/bin/env bash
set -euo pipefail

logger::_escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//"/\\"}"
  s="${s//$'\n'/}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/}"
  printf '%s' "${s}"
}

logger::_emit() {
  local level="$1" msg="$2"
  local run_id="${KUBEXM_RUN_ID:-default}"
  local step_name="${KUBEXM_STEP_NAME:-}"
  local host="${KUBEXM_HOST:-}"
  local pipeline_name="${KUBEXM_PIPELINE_NAME:-}"
  local task_id="${KUBEXM_TASK_ID:-}"
  local json
  json="{\"level\":\"${level}\",\"msg\":\"$(logger::_escape_json "${msg}")\",\"task_id\":\"${task_id}\",\"pipeline_name\":\"${pipeline_name}\",\"run_id\":\"${run_id}\",\"step_name\":\"${step_name}\",\"host\":\"${host}\"}"
  echo "${json}"
  echo "[${level}] ${msg} (pipeline=${pipeline_name} task=${task_id} step=${step_name} host=${host})" 1>&2
}

logger::debug() { logger::_emit "DEBUG" "$*"; }
logger::info() { logger::_emit "INFO" "$*"; }
logger::warn() { logger::_emit "WARN" "$*"; }
logger::error() { logger::_emit "ERROR" "$*"; }
```

Also emit a human-readable console line (with ANSI color) to **stderr**, and JSON to **stdout**. Include fields: `task_id`, `pipeline_name`, `run_id`, `step_name`, `host`. Define `task_id` source (e.g., `KUBEXM_TASK_ID` set by runner/task layer) and ensure tests validate JSON keys instead of just substring match.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/logger_output.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/logger/logger.sh tests/cases/logger_output.sh

git commit -m "feat: add structured logger"
```

---

### Task 4: Implement Parser wrappers using existing config.sh

**Files:**
- Modify: `internal/parser/parser.sh`
- Test: `tests/cases/parser_load.sh`
- Test: `tests/cases/config_precedence.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/parser_load.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/internal/parser/parser.sh"

export KUBEXM_ROOT="${ROOT}"
export KUBEXM_CLUSTER_NAME="test-01-kubeadm-single"

parser::load_config >/dev/null
parser::load_hosts >/dev/null
```

Ensure the test uses an existing conf cluster directory (e.g., `conf/clusters/test-01-kubeadm-single`).

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/parser_load.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```bash
# internal/parser/parser.sh
#!/usr/bin/env bash
set -euo pipefail

parser::load_config() {
  source "/internal/core/config.sh"
  config::parse_config
}

parser::load_hosts() {
  source "/internal/core/config.sh"
  config::parse_hosts
}
```

Also add a small assertion test that confirms `config.sh` already enforces precedence (CLI > ENV > YAML > defaults) so we do not change fields. Confirm the actual getter and CLI override variable names in `lib/core/config.sh` before writing the test.

```bash
# tests/cases/config_precedence.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/lib/core/config.sh"

export KUBEXM_ROOT="${ROOT}"
export KUBEXM_CLUSTER_NAME="test-01-kubeadm-single"

# YAML value
config::parse_config
yaml_val="$(config::get_kubernetes_version)"

# ENV override
export KUBEXM_KUBERNETES_VERSION="v9.9.9"
config::parse_config
env_val="$(config::get_kubernetes_version)"

# CLI override (simulate by exporting the CLI override variable used by config.sh)
export KUBEXM_CLI_KUBERNETES_VERSION="v8.8.8"
config::parse_config
cli_val="$(config::get_kubernetes_version)"

[[ "${yaml_val}" != "${env_val}" ]]
[[ "${env_val}" != "${cli_val}" ]]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/parser_load.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/parser/parser.sh tests/cases/parser_load.sh tests/cases/config_precedence.sh

git commit -m "feat: add parser wrappers"
```

---

## Chunk 2: Execution Layers (Runner/Connector/Steps/Pipeline)

### Task 5: Add Runner and Connector skeleton (SSH-only)

**Files:**
- Create: `internal/runner/runner.sh`
- Create: `internal/connector/connector.sh`
- Test: `tests/cases/runner_connector.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/runner_connector.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/internal/runner/runner.sh"
source "${ROOT}/internal/connector/connector.sh"

connector::exec "localhost" "echo ok" >/dev/null
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/runner_connector.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```bash
# internal/connector/connector.sh
#!/usr/bin/env bash
set -euo pipefail

connector::exec() {
  local host="$1" cmd="$2"
  if [[ "${host}" == "localhost" || "${host}" == "127.0.0.1" ]]; then
    echo "localhost/127.0.0.1 forbidden" >&2
    return 2
  fi
  source "/internal/core/ssh.sh"
  ssh::execute "${host}" "${cmd}"
}

connector::copy() {
  local src="$1" dest="$2" host="$3"
  if [[ "${host}" == "localhost" || "${host}" == "127.0.0.1" ]]; then
    echo "localhost/127.0.0.1 forbidden" >&2
    return 2
  fi
  source "/internal/core/ssh.sh"
  ssh::copy "${src}" "${dest}" "${host}"
}
```

Also add a helper to resolve local primary IP (used when no host list specified) and enforce SSH to that address instead of localhost.

```bash
# internal/runner/runner.sh
#!/usr/bin/env bash
set -euo pipefail

runner::exec() {
  local step_name="$1" ctx="$2" host="$3"
  KUBEXM_STEP_NAME="${step_name}"
  KUBEXM_HOST="${host}"
  "step::${step_name}::check" "${ctx}" && return 0
  "step::${step_name}::run" "${ctx}"
  "step::${step_name}::check" "${ctx}"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/runner_connector.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/runner/runner.sh internal/connector/connector.sh tests/cases/runner_connector.sh

git commit -m "feat: add runner and connector skeleton"
```

---

### Task 6: Step registry + sample step adapter

**Files:**
- Create: `internal/step/registry.sh`
- Create: `internal/step/steps/check_os.sh`
- Test: `tests/cases/step_registry.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/step_registry.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/internal/step/registry.sh"

step::register "check.os" "${ROOT}/internal/step/steps/check_os.sh"
step::load "check.os"
step::check.os::check >/dev/null
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/step_registry.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```bash
# internal/step/registry.sh
#!/usr/bin/env bash
set -euo pipefail

declare -A KUBEXM_STEP_REGISTRY=()

step::register() {
  local name="$1" path="$2"
  KUBEXM_STEP_REGISTRY["${name}"]="${path}"
}

step::load() {
  local name="$1"
  source "${KUBEXM_STEP_REGISTRY["${name}"]}"
}
```

```bash
# internal/step/steps/check_os.sh
#!/usr/bin/env bash
set -euo pipefail

step::check.os::check() { return 0; }
step::check.os::run() { return 0; }
step::check.os::rollback() { return 0; }
step::check.os::targets() { echo "localhost"; }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/step_registry.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/step/registry.sh internal/step/steps/check_os.sh tests/cases/step_registry.sh

git commit -m "feat: add step registry and sample step"
```

---

### Task 7: Pipeline/Module/Task wiring (minimal)

**Files:**
- Create: `internal/pipeline/pipeline.sh`
- Create: `internal/module/module.sh`
- Create: `internal/task/task.sh`
- Test: `tests/cases/pipeline_flow.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/pipeline_flow.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/internal/pipeline/pipeline.sh"
source "${ROOT}/internal/module/module.sh"
source "${ROOT}/internal/task/task.sh"

pipeline::run "demo" "ctx"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/pipeline_flow.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```bash
# internal/pipeline/pipeline.sh
#!/usr/bin/env bash
set -euo pipefail

pipeline::run() {
  local pipeline_name="$1" ctx="$2"
  KUBEXM_PIPELINE_NAME="${pipeline_name}"
  module::run "cluster.prepare" "${ctx}"
}
```

```bash
# internal/module/module.sh
#!/usr/bin/env bash
set -euo pipefail

module::run() {
  local module_name="$1" ctx="$2"
  task::run "system.check" "${ctx}"
}
```

```bash
# internal/task/task.sh
#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/runner/runner.sh"
source "${KUBEXM_ROOT}/internal/step/registry.sh"

# minimal: one step

task::run() {
  local task_name="$1" ctx="$2"
  step::register "check.os" "${KUBEXM_ROOT}/internal/step/steps/check_os.sh"
  step::load "check.os"
  for host in $(step::check.os::targets "${ctx}"); do
    runner::exec "check.os" "${ctx}" "${host}"
  done
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/pipeline_flow.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/pipeline/pipeline.sh internal/module/module.sh internal/task/task.sh tests/cases/pipeline_flow.sh

git commit -m "feat: wire minimal pipeline flow"
```

---

### Task 8: CLI routing to pipeline

**Files:**
- Modify: `bin/kubexm: main dispatch section`
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

Update `bin/kubexm` command dispatch to initialize context + parser and call `pipeline::run` for a selected subcommand (start with `create cluster`).

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/cli_pipeline_dispatch.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add bin/kubexm tests/cases/cli_pipeline_dispatch.sh

git commit -m "feat: route cli to pipeline"
```

---

### Task 9: Step adapters for key phases

Add offline tooling coverage: ensure jq/yq (including xmjq/xmyq) and any required deployment tools are included in offline packages or precompiled binaries, and verify the steps check for their presence before execution.

**Files:**
- Create: `internal/step/steps/*` (wrap existing internal/step/legacy/phases)
- Modify: `internal/task/task.sh` (call new steps)
- Test: `tests/cases/idempotency_steps.sh` (extend existing)

- [ ] **Step 1: Write the failing test**

Add a new check in `tests/cases/idempotency_steps.sh` ensuring new Step names are registered and callable.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/idempotency_steps.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create step adapters that call existing phase functions (read-only). Each adapter should implement `targets`, `check`, `run`, `rollback` with idempotent check.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/idempotency_steps.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/step/steps internal/task/task.sh tests/cases/idempotency_steps.sh

git commit -m "feat: add step adapters"
```

---

### Task 10: Cleanup legacy directories after verification

**Files:**
- Remove: legacy directories no longer referenced (decide after successful pipeline run)
- Test: `tests/run-tests.sh`

- [ ] **Step 1: Identify unused legacy paths**

Locate remaining `internal/step/legacy/phases` and `lib/*` paths not referenced by the new internal pipeline flow.

- [ ] **Step 2: Remove unused directories**

Delete legacy directories that are no longer referenced.

- [ ] **Step 3: Run tests to verify**

Run: `bash tests/run-tests.sh unit`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add internal/ internal/pipeline/pipeline.sh internal/task/task.sh internal/step/steps internal/runner/runner.sh internal/connector/connector.sh

git commit -m "chore: remove legacy directories"
```

---

## Chunk 3: Verification and Hardening

### Task 11: End-to-end dry-run for one cluster config

**Files:**
- Modify: `internal/pipeline/pipeline.sh` (dry-run flag)
- Test: `tests/cases/pipeline_dry_run.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/cases/pipeline_dry_run.sh
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

output="$(KUBEXM_ROOT="${ROOT}" KUBEXM_DRY_RUN=true bash ${ROOT}/bin/kubexm create cluster --cluster test-01-kubeadm-single 2>/dev/null || true)"
[[ "${output}" == *"DRY-RUN"* ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/pipeline_dry_run.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Add dry-run mode in pipeline/runner to only log planned steps and hosts.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/pipeline_dry_run.sh`
Expected: PASS

- [ ] **Step 5: Commit**

Skip (repository not using git).

---

### Task 12: Full test suite

**Files:**
- Test: `tests/run-tests.sh`

- [ ] **Step 1: Run tests**

Run: `bash tests/run-tests.sh`
Expected: PASS (note any skipped sections)

- [ ] **Step 2: Summarize results**

Capture failing test output and fix before proceeding.

---

Plan complete and saved to `docs/superpowers/plans/2026-03-15-kubexm-script-architecture-refactor.md`. Ready to execute?
