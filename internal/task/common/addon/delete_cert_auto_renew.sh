#!/usr/bin/env bash
set -euo pipefail

step::cluster.delete.cert.auto.renew::check() {
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  if runner::remote_exec "systemctl is-enabled --quiet kubexm-cert-renew.timer" >/dev/null 2>&1; then
    return 1  # timer exists, need to delete
  fi
  return 0  # not enabled, skip
}

step::cluster.delete.cert.auto.renew::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Disabling certificate auto-renew on ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl stop kubexm-cert-renew.timer kubexm-cert-renew.service >/dev/null 2>&1 || true"
  runner::remote_exec "systemctl disable kubexm-cert-renew.timer kubexm-cert-renew.service >/dev/null 2>&1 || true"
  runner::remote_exec "rm -f /etc/systemd/system/kubexm-cert-renew.timer /etc/systemd/system/kubexm-cert-renew.service 2>/dev/null || true"
  runner::remote_exec "systemctl daemon-reload"
  log::info "Certificate auto-renew disabled on ${KUBEXM_HOST}"
}

step::cluster.delete.cert.auto.renew::rollback() { return 0; }

step::cluster.delete.cert.auto.renew::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}