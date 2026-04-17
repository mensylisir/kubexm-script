#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cp.stop.kubelet::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "kubelet" 2>/dev/null; then
    return 1  # kubelet running, need to stop
  fi
  return 0  # kubelet not running, skip
}

step::cluster.scale.cp.stop.kubelet::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Stopping kubelet on ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl stop kubelet >/dev/null 2>&1 || true"
}

step::cluster.scale.cp.stop.kubelet::rollback() { return 0; }

step::cluster.scale.cp.stop.kubelet::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}