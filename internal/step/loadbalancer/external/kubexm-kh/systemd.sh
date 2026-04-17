#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kh.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # Both haproxy and keepalived must be running
  if step::check::remote_service_running "${KUBEXM_HOST}" "haproxy" 2>/dev/null &&
     step::check::remote_service_running "${KUBEXM_HOST}" "keepalived" 2>/dev/null; then
    return 0  # both running, skip
  fi
  return 1  # need to start
}

step::lb.external.kubexm.kh.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl enable haproxy keepalived && systemctl restart haproxy keepalived"
}

step::lb.external.kubexm.kh.systemd::rollback() { return 0; }

step::lb.external.kubexm.kh.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
