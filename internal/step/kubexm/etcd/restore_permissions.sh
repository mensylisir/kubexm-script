#!/usr/bin/env bash
set -euo pipefail

step::etcd.restore.permissions::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # Check if etcd data directory exists
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/var/lib/etcd" 2>/dev/null; then
    return 1  # directory exists, need to set permissions
  fi
  return 0
}

step::etcd.restore.permissions::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Setting etcd permissions on ${KUBEXM_HOST}..."
  runner::remote_exec "chown -R etcd:etcd /var/lib/etcd && chmod -R 700 /var/lib/etcd"
}

step::etcd.restore.permissions::rollback() { return 0; }

step::etcd.restore.permissions::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}