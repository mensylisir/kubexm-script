#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.join.worker.run::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/kubeadm-config.yaml"
}

step::kubeadm.join.worker.run::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "kubeadm join --config /etc/kubernetes/kubeadm-config.yaml" || {
    log::error "kubeadm join failed on worker ${KUBEXM_HOST}"
    return 1
  }

  # 验证节点是否成功加入集群并进入 Ready 状态
  log::info "Verifying worker node ${KUBEXM_HOST} joined successfully..."
  local wait_count=0
  local node_name
  node_name=$(config::get_host_param "${KUBEXM_HOST}" "name" 2>/dev/null || hostname -s 2>/dev/null || echo "${KUBEXM_HOST}")

  while [[ ${wait_count} -lt 30 ]]; do
    local node_status
    node_status=$(runner::remote_exec "kubectl get node ${node_name} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null || echo 'Unknown'" || echo "Unknown")
    if [[ "${node_status}" == "True" ]]; then
      log::info "Worker node ${node_name} is Ready"
      return 0
    fi
    wait_count=$((wait_count + 1))
    sleep 2
  done

  log::warn "Worker node ${node_name} joined but not yet Ready (may take a few minutes)"
  return 0
}

step::kubeadm.join.worker.run::rollback() { return 0; }

step::kubeadm.join.worker.run::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
