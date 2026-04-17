#!/usr/bin/env bash
set -euo pipefail

step::cluster.etcd.auto.backup.copy::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/usr/local/bin/etcd-backup.sh"; then
    return 0
  fi
  return 1
}

step::cluster.etcd.auto.backup.copy::run() {
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

  local script_file service_file timer_file
  script_file="$(context::get "etcd_backup_script")"
  service_file="$(context::get "etcd_backup_service")"
  timer_file="$(context::get "etcd_backup_timer")"

  runner::remote_exec "mkdir -p /usr/local/bin /etc/systemd/system"
  runner::remote_copy_file "${script_file}" "/usr/local/bin/etcd-backup.sh"
  runner::remote_exec "chmod +x /usr/local/bin/etcd-backup.sh"
  runner::remote_copy_file "${service_file}" "/etc/systemd/system/etcd-backup.service"
  runner::remote_copy_file "${timer_file}" "/etc/systemd/system/etcd-backup.timer"
}

step::cluster.etcd.auto.backup.copy::rollback() { return 0; }

step::cluster.etcd.auto.backup.copy::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
