#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Etcd Task - Backup/Restore
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::backup_etcd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.backup.collect:${KUBEXM_ROOT}/internal/step/kubexm/etcd/backup_collect.sh" \
    "etcd.backup.copy:${KUBEXM_ROOT}/internal/step/kubexm/etcd/backup_copy.sh" \
    "etcd.backup.verify:${KUBEXM_ROOT}/internal/step/kubexm/etcd/backup_verify.sh"
}

task::restore_etcd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.restore.prebackup:${KUBEXM_ROOT}/internal/step/kubexm/etcd/restore_prebackup.sh" \
    "etcd.restore.stop:${KUBEXM_ROOT}/internal/step/kubexm/etcd/restore_stop.sh" \
    "etcd.restore.copy:${KUBEXM_ROOT}/internal/step/kubexm/etcd/restore_copy.sh" \
    "etcd.restore.permissions:${KUBEXM_ROOT}/internal/step/kubexm/etcd/restore_permissions.sh" \
    "etcd.restore.start:${KUBEXM_ROOT}/internal/step/kubexm/etcd/restore_start.sh"
}

export -f task::backup_etcd
export -f task::restore_etcd
