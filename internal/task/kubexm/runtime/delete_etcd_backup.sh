#!/usr/bin/env bash
set -euo pipefail

step::cluster.delete.etcd.backup::check() {
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  if runner::remote_exec "systemctl is-enabled --quiet etcd-backup.timer" >/dev/null 2>&1; then
    return 1  # timer exists, need to delete
  fi
  return 0  # not enabled, skip
}

step::cluster.delete.etcd.backup::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Disabling etcd backup on ${KUBEXM_HOST}..."
  runner::remote_exec "systemctl stop etcd-backup.timer etcd-backup.service >/dev/null 2>&1 || true"
  runner::remote_exec "systemctl disable etcd-backup.timer etcd-backup.service >/dev/null 2>&1 || true"
  runner::remote_exec "rm -f /etc/systemd/system/etcd-backup.timer /etc/systemd/system/etcd-backup.service 2>/dev/null || true"
  runner::remote_exec "systemctl daemon-reload"
  log::info "Etcd backup disabled on ${KUBEXM_HOST}"
}

step::cluster.delete.etcd.backup::rollback() { return 0; }

step::cluster.delete.etcd.backup::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}