#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.haproxy.systemd.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "haproxy" 2>/dev/null; then
    return 0  # already running, skip
  fi
  return 1  # not running, need to start
}

step::lb.internal.haproxy.systemd.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl daemon-reload && systemctl enable haproxy && systemctl restart haproxy"
}

step::lb.internal.haproxy.systemd.systemd::rollback() { return 0; }

step::lb.internal.haproxy.systemd.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
