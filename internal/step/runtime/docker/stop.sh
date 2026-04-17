#!/usr/bin/env bash
set -euo pipefail

step::runtime.cri.dockerd.stop::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "cri-dockerd" 2>/dev/null; then
    return 1  # running, need to stop
  fi
  return 0  # not running, skip
}

step::runtime.cri.dockerd.stop::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Stopping cri-dockerd on ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl stop cri-dockerd >/dev/null 2>&1 || true"
}

step::runtime.cri.dockerd.stop::rollback() { return 0; }

step::runtime.cri.dockerd.stop::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}