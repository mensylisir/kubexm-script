#!/usr/bin/env bash
set -euo pipefail

step::cluster.etcd.auto.backup.enable::check() {
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  if runner::remote_exec "systemctl is-enabled --quiet etcd-backup.timer" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

step::cluster.etcd.auto.backup.enable::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local enabled
  enabled="$(context::get "etcd_backup_enabled" || echo "false")"
  if [[ "${enabled}" != "true" ]]; then
    return 0
  fi

  runner::remote_exec "systemctl daemon-reload && systemctl enable etcd-backup.timer && systemctl start etcd-backup.timer"
}

step::cluster.etcd.auto.backup.enable::rollback() { return 0; }

step::cluster.etcd.auto.backup.enable::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
