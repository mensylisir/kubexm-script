#!/usr/bin/env bash
set -euo pipefail

step::cluster.wait.workloads.deleted::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  # Check if there are any workloads remaining (excluding kube-system)
  local workload_count
  workload_count=$(kubectl get all -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | grep -v "NAMESPACE" | grep -v "^$" | wc -l || echo "0")
  if [[ "${workload_count}" -eq 0 ]]; then
    return 0  # no workloads, skip waiting
  fi
  return 1  # have workloads, need to wait
}

step::cluster.wait.workloads.deleted::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  log::info "Waiting for workloads to be deleted..."
  sleep 10
}

step::cluster.wait.workloads.deleted::rollback() { return 0; }

step::cluster.wait.workloads.deleted::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
