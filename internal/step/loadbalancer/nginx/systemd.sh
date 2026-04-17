#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.nginx.systemd.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "nginx" 2>/dev/null; then
    return 0  # already running, skip
  fi
  return 1  # not running, need to start
}

step::lb.internal.nginx.systemd.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl daemon-reload && systemctl enable nginx && systemctl restart nginx"
}

step::lb.internal.nginx.systemd.systemd::rollback() { return 0; }

step::lb.internal.nginx.systemd.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
