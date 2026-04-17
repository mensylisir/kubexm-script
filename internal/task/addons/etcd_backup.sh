#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Addon Task - etcd auto backup
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_etcd_backup_config() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.etcd.auto.backup.collect:${KUBEXM_ROOT}/internal/task/common/etcd_auto_backup_collect.sh"
}

task::install_etcd_backup() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.etcd.auto.backup.copy:${KUBEXM_ROOT}/internal/task/common/etcd_auto_backup_copy.sh" \
    "cluster.etcd.auto.backup.enable:${KUBEXM_ROOT}/internal/task/common/etcd_auto_backup_enable.sh"
}

task::delete_etcd_backup() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.delete.etcd.backup:${KUBEXM_ROOT}/internal/task/common/delete_etcd_backup.sh"
}

export -f task::collect_etcd_backup_config
export -f task::install_etcd_backup
export -f task::delete_etcd_backup