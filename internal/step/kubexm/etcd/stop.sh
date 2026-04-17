#!/usr/bin/env bash
set -euo pipefail

step::etcd.stop::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "etcd" 2>/dev/null; then
    return 1
  fi
  return 0
}

step::etcd.stop::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Stopping etcd on ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl stop etcd >/dev/null 2>&1 || true"
}

step::etcd.stop::rollback() { return 0; }

step::etcd.stop::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}