#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.control.plane.apply::check() { return 1; }

step::cluster.upgrade.control.plane.apply::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local target_version first_master_ip
  target_version="$(context::get "cluster_upgrade_target_version")"
  first_master_ip="$(context::get "cluster_upgrade_first_master_ip")"

  if [[ -n "${first_master_ip}" && "${KUBEXM_HOST}" == "${first_master_ip}" ]]; then
    runner::remote_exec "kubeadm upgrade plan ${target_version}"
    runner::remote_exec "kubeadm upgrade apply ${target_version} -y"
  else
    runner::remote_exec "kubeadm upgrade node"
  fi
}

step::cluster.upgrade.control.plane.apply::rollback() { return 0; }

step::cluster.upgrade.control.plane.apply::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
