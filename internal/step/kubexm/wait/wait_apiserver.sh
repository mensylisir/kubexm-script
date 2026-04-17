#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.wait.apiserver::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "kube-apiserver" 2>/dev/null; then
    return 0
  fi
  return 1
}

step::kubernetes.wait.apiserver::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local max_attempts attempt=1
  max_attempts=${KUBEXM_CONTROL_PLANE_WAIT_RETRIES:-24}
  while [[ ${attempt} -le ${max_attempts} ]]; do
    if runner::remote_exec "systemctl is-active kube-apiserver >/dev/null 2>&1"; then
      log::info "kube-apiserver is active on ${KUBEXM_HOST}"
      return 0
    fi
    log::info "Waiting for kube-apiserver on ${KUBEXM_HOST}... (${attempt}/${max_attempts})"
    attempt=$((attempt + 1))
    sleep 5
  done

  log::error "kube-apiserver not ready on ${KUBEXM_HOST}"
  return 1
}

step::kubernetes.wait.apiserver::rollback() { return 0; }

step::kubernetes.wait.apiserver::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
