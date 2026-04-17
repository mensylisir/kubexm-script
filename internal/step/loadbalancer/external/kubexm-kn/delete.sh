#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kn.delete::check() {
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  # Check if nginx or keepalived is enabled
  if runner::remote_exec "systemctl is-enabled --quiet nginx" >/dev/null 2>&1; then
    return 1  # enabled, need to delete
  fi
  return 0  # not enabled, skip
}

step::lb.external.kubexm.kn.delete::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Deleting kubexm-kn LB on ${KUBEXM_HOST}..."

  # Stop and disable services
  runner::remote_exec "systemctl stop nginx keepalived >/dev/null 2>&1 || true"
  runner::remote_exec "systemctl disable nginx keepalived >/dev/null 2>&1 || true"

  # Remove systemd service files
  runner::remote_exec "rm -f /etc/systemd/system/nginx.service /etc/systemd/system/keepalived.service 2>/dev/null || true"

  # Remove config files
  runner::remote_exec "rm -rf /etc/nginx /etc/keepalived 2>/dev/null || true"

  # Remove check scripts
  runner::remote_exec "rm -f /usr/local/bin/kubexm-*check*.sh 2>/dev/null || true"

  runner::remote_exec "systemctl daemon-reload"
  log::info "kubexm-kn LB deleted from ${KUBEXM_HOST}"
}

step::lb.external.kubexm.kn.delete::rollback() { return 0; }

step::lb.external.kubexm.kn.delete::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}