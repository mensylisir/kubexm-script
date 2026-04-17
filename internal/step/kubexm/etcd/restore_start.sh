#!/usr/bin/env bash
set -euo pipefail

step::etcd.restore.start::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "etcd" 2>/dev/null; then
    return 0
  fi
  return 1
}

step::etcd.restore.start::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Starting etcd after restore on ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl start etcd"
  sleep 5
  log::info "Etcd started on ${KUBEXM_HOST}"
}

step::etcd.restore.start::rollback() { return 0; }

step::etcd.restore.start::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}