#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.control.plane.restart::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "kubelet" 2>/dev/null; then
    return 0
  fi
  return 1
}

step::cluster.upgrade.control.plane.restart::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local node_name
  node_name="$(context::get "cluster_upgrade_node_name")"

  runner::remote_exec "systemctl daemon-reload && systemctl restart kubelet"
  kubectl uncordon "${node_name}"
  log::info "Control plane node ${node_name} upgraded"
}

step::cluster.upgrade.control.plane.restart::rollback() { return 0; }

step::cluster.upgrade.control.plane.restart::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
