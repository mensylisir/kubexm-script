#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.join.master.run::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/kubeadm-config.yaml"
}

step::kubeadm.join.master.run::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "kubeadm join --config /etc/kubernetes/kubeadm-config.yaml"
}

step::kubeadm.join.master.run::rollback() { return 0; }

step::kubeadm.join.master.run::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
