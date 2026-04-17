#!/usr/bin/env bash
set -euo pipefail

step::cluster.reset.kubeadm.cmd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # 如果节点不可达，跳过
  if ! step::check::host_reachable 5; then
    return 0
  fi
  if step::check::remote_command_exists "${KUBEXM_HOST}" "kubeadm" 2>/dev/null; then
    return 1
  fi
  return 0
}

step::cluster.reset.kubeadm.cmd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "command -v kubeadm >/dev/null 2>&1 && kubeadm reset --force >/dev/null 2>&1 || true"
}

step::cluster.reset.kubeadm.cmd::rollback() { return 0; }

step::cluster.reset.kubeadm.cmd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
