#!/usr/bin/env bash
set -euo pipefail

step::etcd.upgrade.start::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "etcd" 2>/dev/null; then
    return 0
  fi
  return 1
}

step::etcd.upgrade.start::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local node_name
  node_name="$(context::get "etcd_upgrade_node_name" || true)"
  runner::remote_exec "systemctl start etcd"
  log::info "Waiting for etcd to be healthy on ${node_name}..."
  sleep 5
}

step::etcd.upgrade.start::rollback() { return 0; }

step::etcd.upgrade.start::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}
