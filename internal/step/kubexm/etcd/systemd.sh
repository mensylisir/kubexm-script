#!/usr/bin/env bash
set -euo pipefail

step::etcd.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # If etcd is already running, skip starting it
  if step::check::remote_service_running "${KUBEXM_HOST}" "etcd" 2>/dev/null; then
    return 0  # already running, skip
  fi
  return 1  # not running, need to start
}

step::etcd.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl daemon-reload && systemctl enable etcd && systemctl start etcd"
}

step::etcd.systemd::rollback() { return 0; }

step::etcd.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
