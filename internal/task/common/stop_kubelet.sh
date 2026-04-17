#!/usr/bin/env bash
set -euo pipefail

step::cluster.stop.kubelet::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # 如果节点不可达，跳过
  if ! step::check::host_reachable 5; then
    return 0
  fi
  if step::check::remote_service_running "${KUBEXM_HOST}" "kubelet" 2>/dev/null; then
    return 1
  fi
  return 0
}

step::cluster.stop.kubelet::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Stopping kubelet on ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl is-active --quiet kubelet && systemctl stop kubelet >/dev/null 2>&1 || true"
}

step::cluster.stop.kubelet::rollback() { return 0; }

step::cluster.stop.kubelet::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
