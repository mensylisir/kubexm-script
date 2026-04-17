#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.nginx.systemd.delete::check() {
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  if runner::remote_exec "systemctl is-enabled --quiet nginx" >/dev/null 2>&1; then
    return 1  # enabled, need to delete
  fi
  return 0  # not enabled, skip
}

step::lb.internal.nginx.systemd.delete::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Deleting internal nginx systemd from ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl stop nginx >/dev/null 2>&1 || true"
  runner::remote_exec "systemctl disable nginx >/dev/null 2>&1 || true"
  runner::remote_exec "rm -f /etc/systemd/system/nginx.service /etc/nginx/nginx.conf 2>/dev/null || true"
  runner::remote_exec "systemctl daemon-reload"
  log::info "Internal nginx systemd deleted from ${KUBEXM_HOST}"
}

step::lb.internal.nginx.systemd.delete::rollback() { return 0; }

step::lb.internal.nginx.systemd.delete::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}

# Alias for static pod mode
step::lb.internal.nginx.static.delete::check() { step::lb.internal.nginx.systemd.delete::check "$@"; }
step::lb.internal.nginx.static.delete::run() { step::lb.internal.nginx.systemd.delete::run "$@"; }
step::lb.internal.nginx.static.delete::rollback() { step::lb.internal.nginx.systemd.delete::rollback "$@"; }
step::lb.internal.nginx.static.delete::targets() { step::lb.internal.nginx.systemd.delete::targets "$@"; }
