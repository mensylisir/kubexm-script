# Scale Control-plane Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement control-plane node scale-out and scale-in support in kubexm scale cluster flow.

**Architecture:** Add new `cluster.scale_cp_*` steps that handle control-plane nodes separately from workers. The existing `cluster.scale_*` worker steps remain unchanged. New steps are gated by `--action=scale-out-cp` or `--action=scale-in-cp`.

**Tech Stack:** Bash, existing step framework, kubectl, kubeadm

---

## File Structure

### New Files (9 step files)

- `internal/step/steps/cluster_scale_cp_join_collect_action.sh`
- `internal/step/steps/cluster_scale_cp_join_collect_node.sh`
- `internal/step/steps/cluster_scale_cp_join_collect_command.sh`
- `internal/step/steps/cluster_scale_cp_join_exec.sh`
- `internal/step/steps/cluster_scale_cp_drain_nodes.sh`
- `internal/step/steps/cluster_scale_cp_remove_nodes.sh`
- `internal/step/steps/cluster_scale_cp_stop_kubelet.sh`
- `internal/step/steps/cluster_scale_cp_kubeadm_reset.sh`
- `internal/step/steps/cluster_scale_cp_cleanup_dirs.sh`

### Modify Files

- `internal/task/scale_cluster.sh:38-55` — register new steps

---

## Task 1: cluster_scale_cp_join_collect_action.sh

**Files:**
- Create: `internal/step/steps/cluster_scale_cp_join_collect_action.sh`
- Test: `tests/cases/scale_cp_join_collect_action.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
export KUBEXM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_action.sh"

# Test: check returns 0 when action is scale-out-cp
# (mock context to avoid dependency on full setup)
export KUBEXM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
touch "${KUBEXM_ROOT}/tmp_test_context_dir"
KUBEXM_CONTEXT_DIR="${KUBEXM_ROOT}/tmp_test_context_dir" bash -c '
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  context::init
  source "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_action.sh"
  step::cluster.scale_cp_join_collect_action::run "ctx" "--action=scale-out-cp"
'
result=$(context::get "cluster_scale_cp_action" || echo "NOT_SET")
[[ "${result}" == "scale-out-cp" ]]
rm -rf "${KUBEXM_ROOT}/tmp_test_context_dir"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/scale_cp_join_collect_action.sh`
Expected: FAIL with "file not found"

- [ ] **Step 3: Write minimal implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_join_collect_action::check() { return 1; }

step::cluster.scale_cp_join_collect_action::run() {
  local ctx="$1"
  shift
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  if [[ "${action}" != "scale-out-cp" && "${action}" != "scale-in-cp" ]]; then
    context::set "cluster_scale_cp_skip" "true"
    return 0
  fi
  context::set "cluster_scale_cp_skip" "false"
  context::set "cluster_scale_cp_action" "${action}"
}

step::cluster.scale_cp_join_collect_action::rollback() { return 0; }

step::cluster.scale_cp_join_collect_action::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-out-cp" && "${action}" != "scale-in-cp" ]]; then
    return 0
  fi
  # Return first master IP as the single target for action collection
  local masters first first_ip=""
  masters=$(config::get_role_members 'control-plane')
  first=$(echo "${masters}" | awk '{print $1}')
  first_ip=$(config::get_host_param "${first}" "address")
  echo "${first_ip}"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/scale_cp_join_collect_action.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/step/steps/cluster_scale_cp_join_collect_action.sh tests/cases/scale_cp_join_collect_action.sh
git commit -m "feat: add cluster_scale_cp_join_collect_action step"
```

---

## Task 2: cluster_scale_cp_join_collect_node.sh

**Files:**
- Create: `internal/step/steps/cluster_scale_cp_join_collect_node.sh`
- Test: `tests/cases/scale_cp_join_collect_node.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
export KUBEXM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Test verifies targets() returns non-first master IPs for scale-out-cp
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cases/scale_cp_join_collect_node.sh`
Expected: FAIL with "file not found"

- [ ] **Step 3: Write minimal implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_join_collect_node::check() { return 1; }

step::cluster.scale_cp_join_collect_node::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  local node_name=""
  local masters node node_ip
  masters=$(config::get_role_members 'control-plane')
  for node in ${masters}; do
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ -n "${node_ip}" && "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  context::set "cluster_scale_cp_node" "${node_name}"
}

step::cluster.scale_cp_join_collect_node::rollback() { return 0; }

step::cluster.scale_cp_join_collect_node::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-out-cp" ]]; then
    return 0
  fi

  local masters current_nodes nodes_to_join=""
  masters=$(config::get_role_members 'control-plane')
  current_nodes=$(kubectl get nodes -o name 2>/dev/null | sed 's/node\\///g' || echo "")
  local first
  first=$(echo "${masters}" | awk '{print $1}')

  local node
  for node in ${masters}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    if [[ ! "${current_nodes}" =~ ${node} ]]; then
      nodes_to_join="${nodes_to_join} ${node}"
    fi
  done

  local out=""
  for node in ${nodes_to_join}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -z "${node_ip}" ]] && continue
    out+="${node_ip} "
  done
  echo "${out}"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cases/scale_cp_join_collect_node.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/step/steps/cluster_scale_cp_join_collect_node.sh tests/cases/scale_cp_join_collect_node.sh
git commit -m "feat: add cluster_scale_cp_join_collect_node step"
```

---

## Task 3: cluster_scale_cp_join_collect_command.sh

**Files:**
- Create: `internal/step/steps/cluster_scale_cp_join_collect_command.sh`

- [ ] **Step 1: Write the implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_join_collect_command::check() { return 1; }

step::cluster.scale_cp_join_collect_command::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  # Load kubeadm join params set by kubeadm.join_master_load_params
  local cluster_name join_token ca_hash cert_key first_master_ip
  cluster_name="$(context::get "kubeadm_join_master_cluster_name" || true)"
  join_token="$(context::get "kubeadm_join_master_join_token" || true)"
  ca_hash="$(context::get "kubeadm_join_master_ca_hash" || true)"
  cert_key="$(context::get "kubeadm_join_master_cert_key" || true)"
  first_master_ip="$(context::get "kubeadm_join_master_first_master_ip" || true)"

  if [[ -z "${join_token}" || -z "${ca_hash}" || -z "${cert_key}" ]]; then
    log::error "Missing kubeadm join parameters for control-plane"
    return 1
  fi

  local node_name
  node_name="$(context::get "cluster_scale_cp_node" || true)"
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  local join_command="kubeadm join ${first_master_ip}:6443 --token ${join_token} --discovery-token-ca-cert-hash ${ca_hash} --control-plane --certificate-key ${cert_key} --node-name ${node_name}"

  context::set "cluster_scale_cp_cmd" "${join_command}"
}

step::cluster.scale_cp_join_collect_command::rollback() { return 0; }

step::cluster.scale_cp_join_collect_command::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-out-cp" ]]; then
    return 0
  fi

  local masters current_nodes nodes_to_join=""
  masters=$(config::get_role_members 'control-plane')
  current_nodes=$(kubectl get nodes -o name 2>/dev/null | sed 's/node\\///g' || echo "")
  local first
  first=$(echo "${masters}" | awk '{print $1}')

  local node
  for node in ${masters}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    if [[ ! "${current_nodes}" =~ ${node} ]]; then
      nodes_to_join="${nodes_to_join} ${node}"
    fi
  done

  local out=""
  for node in ${nodes_to_join}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -z "${node_ip}" ]] && continue
    out+="${node_ip} "
  done
  echo "${out}"
}
```

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n internal/step/steps/cluster_scale_cp_join_collect_command.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add internal/step/steps/cluster_scale_cp_join_collect_command.sh
git commit -m "feat: add cluster_scale_cp_join_collect_command step"
```

---

## Task 4: cluster_scale_cp_join_exec.sh

**Files:**
- Create: `internal/step/steps/cluster_scale_cp_join_exec.sh`

- [ ] **Step 1: Write the implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_join_exec::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip execution
  fi
  return 1  # need to execute join
}

step::cluster.scale_cp_join_exec::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  local node_name join_command
  node_name="$(context::get "cluster_scale_cp_node" || true)"
  join_command="$(context::get "cluster_scale_cp_cmd" || true)"

  if [[ -z "${join_command}" ]]; then
    log::error "No join command found for control-plane node"
    return 1
  fi

  runner::remote_exec "${join_command}"
  log::info "Control-plane node ${node_name} joined successfully"
}

step::cluster.scale_cp_join_exec::rollback() { return 0; }

step::cluster.scale_cp_join_exec::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-out-cp" ]]; then
    return 0
  fi

  local masters current_nodes nodes_to_join=""
  masters=$(config::get_role_members 'control-plane')
  current_nodes=$(kubectl get nodes -o name 2>/dev/null | sed 's/node\\///g' || echo "")
  local first
  first=$(echo "${masters}" | awk '{print $1}')

  local node
  for node in ${masters}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    if [[ ! "${current_nodes}" =~ ${node} ]]; then
      nodes_to_join="${nodes_to_join} ${node}"
    fi
  done

  local out=""
  for node in ${nodes_to_join}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -z "${node_ip}" ]] && continue
    out+="${node_ip} "
  done
  echo "${out}"
}
```

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n internal/step/steps/cluster_scale_cp_join_exec.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add internal/step/steps/cluster_scale_cp_join_exec.sh
git commit -m "feat: add cluster_scale_cp_join_exec step"
```

---

## Task 5: cluster_scale_cp_drain_nodes.sh

**Files:**
- Create: `internal/step/steps/cluster_scale_cp_drain_nodes.sh`

- [ ] **Step 1: Write the implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_drain_nodes::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  return 1  # need to drain
}

step::cluster.scale_cp_drain_nodes::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  local node_name
  node_name="$(context::get "cluster_scale_cp_node" || true)"
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  log::info "Draining control-plane node: ${node_name}"
  if ! kubectl get node "${node_name}" &>/dev/null; then
    log::warn "Node not found: ${node_name}"
    return 0
  fi
  if ! kubectl drain "${node_name}" --delete-emptydir-data --ignore-daemonsets --force --timeout=300s; then
    log::error "Failed to drain node: ${node_name}"
    return 1
  fi
}

step::cluster.scale_cp_drain_nodes::rollback() { return 0; }

step::cluster.scale_cp_drain_nodes::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-in-cp" ]]; then
    return 0
  fi

  local masters first out=""
  masters=$(config::get_role_members 'control-plane')
  first=$(echo "${masters}" | awk '{print $1}')

  local node
  for node in ${masters}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}
```

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n internal/step/steps/cluster_scale_cp_drain_nodes.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add internal/step/steps/cluster_scale_cp_drain_nodes.sh
git commit -m "feat: add cluster_scale_cp_drain_nodes step"
```

---

## Task 6: cluster_scale_cp_remove_nodes.sh

**Files:**
- Create: `internal/step/steps/cluster_scale_cp_remove_nodes.sh`

- [ ] **Step 1: Write the implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_remove_nodes::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  return 1  # need to remove nodes
}

step::cluster.scale_cp_remove_nodes::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  local node_name
  node_name="$(context::get "cluster_scale_cp_node" || true)"
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  log::info "Removing control-plane node from cluster: ${node_name}"
  if ! kubectl delete node "${node_name}"; then
    log::error "Failed to remove node: ${node_name}"
    return 1
  fi
}

step::cluster.scale_cp_remove_nodes::rollback() { return 0; }

step::cluster.scale_cp_remove_nodes::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-in-cp" ]]; then
    return 0
  fi

  local masters first out=""
  masters=$(config::get_role_members 'control-plane')
  first=$(echo "${masters}" | awk '{print $1}')

  local node
  for node in ${masters}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}
```

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n internal/step/steps/cluster_scale_cp_remove_nodes.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add internal/step/steps/cluster_scale_cp_remove_nodes.sh
git commit -m "feat: add cluster_scale_cp_remove_nodes step"
```

---

## Task 7: Reuse existing worker scale-in steps for CP

The existing `cluster.scale_stop_kubelet`, `cluster.scale_kubeadm_reset`, and `cluster.scale_cleanup_dirs` steps already support scale-in action and use `KUBEXM_HOST` as targets. We need to create CP-specific versions that check for `scale-in-cp` action.

**Files:**
- Create: `internal/step/steps/cluster_scale_cp_stop_kubelet.sh`
- Create: `internal/step/steps/cluster_scale_cp_kubeadm_reset.sh`
- Create: `internal/step/steps/cluster_scale_cp_cleanup_dirs.sh`

- [ ] **Step 1: Create cluster_scale_cp_stop_kubelet.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_stop_kubelet::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  source "${KUBEXM_ROOT}/internal/step/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "kubelet" 2>/dev/null; then
    return 1  # kubelet running, need to stop
  fi
  return 0  # kubelet not running, skip
}

step::cluster.scale_cp_stop_kubelet::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Stopping kubelet on ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl stop kubelet >/dev/null 2>&1 || true"
}

step::cluster.scale_cp_stop_kubelet::rollback() { return 0; }

step::cluster.scale_cp_stop_kubelet::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-in-cp" ]]; then
    return 0
  fi

  local masters first out=""
  masters=$(config::get_role_members 'control-plane')
  first=$(echo "${masters}" | awk '{print $1}')

  local node
  for node in ${masters}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}
```

- [ ] **Step 2: Create cluster_scale_cp_kubeadm_reset.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_kubeadm_reset::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  source "${KUBEXM_ROOT}/internal/step/checks.sh"
  if step::check::remote_command_exists "${KUBEXM_HOST}" "kubeadm" 2>/dev/null; then
    return 1  # kubeadm exists, need to reset
  fi
  return 0  # kubeadm not exists, skip
}

step::cluster.scale_cp_kubeadm_reset::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "kubeadm reset --force >/dev/null 2>&1 || true"
}

step::cluster.scale_cp_kubeadm_reset::rollback() { return 0; }

step::cluster.scale_cp_kubeadm_reset::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-in-cp" ]]; then
    return 0
  fi

  local masters first out=""
  masters=$(config::get_role_members 'control-plane')
  first=$(echo "${masters}" | awk '{print $1}')

  local node
  for node in ${masters}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}
```

- [ ] **Step 3: Create cluster_scale_cp_cleanup_dirs.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale_cp_cleanup_dirs::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  source "${KUBEXM_ROOT}/internal/step/checks.sh"
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/etc/kubernetes"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/var/lib/kubelet"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/var/lib/etcd"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/root/.kube"; then
    return 1
  fi
  return 0  # no dirs to cleanup, skip
}

step::cluster.scale_cp_cleanup_dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube >/dev/null 2>&1 || true"
}

step::cluster.scale_cp_cleanup_dirs::rollback() { return 0; }

step::cluster.scale_cp_cleanup_dirs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-in-cp" ]]; then
    return 0
  fi

  local masters first out=""
  masters=$(config::get_role_members 'control-plane')
  first=$(echo "${masters}" | awk '{print $1}')

  local node
  for node in ${masters}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}
```

- [ ] **Step 4: Verify bash syntax for all three**

Run: `bash -n internal/step/steps/cluster_scale_cp_stop_kubelet.sh && bash -n internal/step/steps/cluster_scale_cp_kubeadm_reset.sh && bash -n internal/step/steps/cluster_scale_cp_cleanup_dirs.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/step/steps/cluster_scale_cp_stop_kubelet.sh internal/step/steps/cluster_scale_cp_kubeadm_reset.sh internal/step/steps/cluster_scale_cp_cleanup_dirs.sh
git commit -m "feat: add cluster_scale_cp scale-in steps (stop kubelet, reset, cleanup)"
```

---

## Task 8: Register steps in task::scale_cluster

**Files:**
- Modify: `internal/task/scale_cluster.sh:38-55`

- [ ] **Step 1: Read current file to understand line numbers**

- [ ] **Step 2: Add new step registrations after existing worker scale steps**

In `task::scale_cluster`, add these step registrations after line 55 (after `cluster.scale_update_lb_kube_vip_notice`):

```bash
"cluster.scale_cp_join_collect_action:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_action.sh" \
"cluster.scale_cp_join_collect_node:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_node.sh" \
"cluster.scale_cp_join_collect_command:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_command.sh" \
"cluster.scale_cp_join_exec:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_exec.sh" \
"cluster.scale_cp_drain_nodes:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_drain_nodes.sh" \
"cluster.scale_cp_remove_nodes:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_remove_nodes.sh" \
"cluster.scale_cp_stop_kubelet:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_stop_kubelet.sh" \
"cluster.scale_cp_kubeadm_reset:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_kubeadm_reset.sh" \
"cluster.scale_cp_cleanup_dirs:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_cleanup_dirs.sh" \
```

- [ ] **Step 3: Also add new steps to the step execution list**

After the existing scale cluster step list (around line 64-66), add the new CP steps. The flow should be:

```bash
task::run_steps "${ctx}" "${args[@]}" -- \
  # Existing worker scale-out steps
  "check.tools_binary:${KUBEXM_ROOT}/internal/step/steps/check_tools_binary.sh" \
  ...
  # New CP scale-out steps (only run when --action=scale-out-cp)
  "cluster.scale_cp_join_collect_action:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_action.sh" \
  "cluster.scale_cp_join_collect_node:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_node.sh" \
  "cluster.scale_cp_join_collect_command:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_command.sh" \
  "cluster.scale_cp_join_exec:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_exec.sh" \
  # New CP scale-in steps (only run when --action=scale-in-cp)
  "cluster.scale_cp_drain_nodes:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_drain_nodes.sh" \
  "cluster.scale_cp_remove_nodes:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_remove_nodes.sh" \
  "cluster.scale_cp_stop_kubelet:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_stop_kubelet.sh" \
  "cluster.scale_cp_kubeadm_reset:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_kubeadm_reset.sh" \
  "cluster.scale_cp_cleanup_dirs:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_cleanup_dirs.sh" \
```

- [ ] **Step 4: Verify syntax**

Run: `bash -n internal/task/scale_cluster.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/task/scale_cluster.sh
git commit -m "feat: register control-plane scale steps in scale_cluster task"
```

---

## Task 9: End-to-end verification

**Files:**
- Test: `tests/cases/scale_cp_e2e.sh`

- [ ] **Step 1: Write integration test**

```bash
#!/usr/bin/env bash
set -euo pipefail
export KUBEXM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Test: verify all CP scale steps are registered and syntax-valid
for step_file in \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_action.sh" \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_node.sh" \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_command.sh" \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_exec.sh" \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_drain_nodes.sh" \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_remove_nodes.sh" \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_stop_kubelet.sh" \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_kubeadm_reset.sh" \
  "${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_cleanup_dirs.sh"; do
  [[ -f "${step_file}" ]] || { echo "missing ${step_file}"; exit 1; }
  bash -n "${step_file}" || { echo "syntax error in ${step_file}"; exit 1; }
done

# Test: verify task file has all registrations
grep -q "cluster.scale_cp_join_collect_action" "${KUBEXM_ROOT}/internal/task/scale_cluster.sh" || { echo "missing registration"; exit 1; }
grep -q "cluster.scale_cp_join_exec" "${KUBEXM_ROOT}/internal/task/scale_cluster.sh" || { echo "missing registration"; exit 1; }
grep -q "cluster.scale_cp_drain_nodes" "${KUBEXM_ROOT}/internal/task/scale_cluster.sh" || { echo "missing registration"; exit 1; }

echo "All CP scale steps verified"
```

- [ ] **Step 2: Run test**

Run: `bash tests/cases/scale_cp_e2e.sh`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add tests/cases/scale_cp_e2e.sh
git commit -m "test: add e2e verification for control-plane scale steps"
```

---

## Summary

After all tasks complete, the scale cluster flow will support:

| Command | Behavior |
|---------|----------|
| `kubexm scale cluster --cluster=X --action=scale-out` | Add worker nodes (existing) |
| `kubexm scale cluster --cluster=X --action=scale-in` | Remove worker nodes (existing) |
| `kubexm scale cluster --cluster=X --action=scale-out-cp` | Add control-plane nodes (new) |
| `kubexm scale cluster --cluster=X --action=scale-in-cp` | Remove control-plane nodes (new) |
