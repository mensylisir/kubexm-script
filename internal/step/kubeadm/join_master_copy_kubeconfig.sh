#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.join.master.copy.kubeconfig::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # Check if kubeconfig already exists on remote
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/root/.kube/config"; then
    return 0  # already exists, skip
  fi
  return 1  # need to copy
}

step::kubeadm.join.master.copy.kubeconfig::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "mkdir -p /root/.kube && cp /etc/kubernetes/admin.conf /root/.kube/config"
}

step::kubeadm.join.master.copy.kubeconfig::rollback() { return 0; }

step::kubeadm.join.master.copy.kubeconfig::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
