#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cp.kubeadm.reset::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_command_exists "${KUBEXM_HOST}" "kubeadm" 2>/dev/null; then
    return 1  # kubeadm exists, need to reset
  fi
  return 0  # kubeadm not exists, skip
}

step::cluster.scale.cp.kubeadm.reset::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "kubeadm reset --force >/dev/null 2>&1 || true"
}

step::cluster.scale.cp.kubeadm.reset::rollback() { return 0; }

step::cluster.scale.cp.kubeadm.reset::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}