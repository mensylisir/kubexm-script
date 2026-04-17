#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.wait.controller.manager::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "kube-controller-manager" 2>/dev/null; then
    return 0
  fi
  return 1
}

step::kubernetes.wait.controller.manager::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local max_attempts attempt=1
  max_attempts=${KUBEXM_CONTROL_PLANE_WAIT_RETRIES:-24}
  while [[ ${attempt} -le ${max_attempts} ]]; do
    if runner::remote_exec "systemctl is-active kube-controller-manager >/dev/null 2>&1"; then
      log::info "kube-controller-manager is active on ${KUBEXM_HOST}"
      return 0
    fi
    log::info "Waiting for kube-controller-manager on ${KUBEXM_HOST}... (${attempt}/${max_attempts})"
    attempt=$((attempt + 1))
    sleep 5
  done

  log::error "kube-controller-manager not ready on ${KUBEXM_HOST}"
  return 1
}

step::kubernetes.wait.controller.manager::rollback() { return 0; }

step::kubernetes.wait.controller.manager::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
