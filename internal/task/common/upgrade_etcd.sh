#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Upgrade Task - Etcd Upgrade
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::upgrade_validate() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.upgrade.validate:${KUBEXM_ROOT}/internal/step/kubexm/etcd/upgrade_validate.sh"
}

task::upgrade_backup() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.upgrade.backup:${KUBEXM_ROOT}/internal/step/kubexm/etcd/upgrade_backup.sh"
}

task::upgrade_collect() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.upgrade.collect:${KUBEXM_ROOT}/internal/step/kubexm/etcd/upgrade_collect.sh"
}

task::upgrade_stop() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.upgrade.stop:${KUBEXM_ROOT}/internal/step/kubexm/etcd/upgrade_stop.sh"
}

task::upgrade_copy_binaries() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.upgrade.copy.binaries:${KUBEXM_ROOT}/internal/step/kubexm/etcd/upgrade_copy_binaries.sh"
}

task::upgrade_start() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.upgrade.start:${KUBEXM_ROOT}/internal/step/kubexm/etcd/upgrade_start.sh"
}

task::upgrade_healthcheck() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.upgrade.healthcheck:${KUBEXM_ROOT}/internal/step/kubexm/etcd/upgrade_healthcheck.sh"
}

# 完整 etcd 升级流程
task::upgrade_etcd() {
  local ctx="$1"
  shift
  task::upgrade_validate "${ctx}" "$@"
  task::upgrade_backup "${ctx}" "$@"
  task::upgrade_collect "${ctx}" "$@"
  task::upgrade_stop "${ctx}" "$@"
  task::upgrade_copy_binaries "${ctx}" "$@"
  task::upgrade_start "${ctx}" "$@"
  task::upgrade_healthcheck "${ctx}" "$@"
}

export -f task::upgrade_validate
export -f task::upgrade_backup
export -f task::upgrade_collect
export -f task::upgrade_stop
export -f task::upgrade_copy_binaries
export -f task::upgrade_start
export -f task::upgrade_healthcheck
export -f task::upgrade_etcd
