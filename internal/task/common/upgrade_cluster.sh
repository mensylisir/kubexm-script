#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Upgrade Task - Cluster Upgrade
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/network/cni/apply.sh"

# 升级前检查
task::upgrade_precheck() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.upgrade.precheck:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_precheck.sh"
}

# 检查版本
task::upgrade_check_version() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.upgrade.check.version:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_check_version.sh"
}

# 升级 Control Plane
task::upgrade_control_plane() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.upgrade.control.plane.collect.target:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_control_plane_collect_target.sh" \
    "cluster.upgrade.control.plane.collect.node:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_control_plane_collect_node.sh" \
    "cluster.upgrade.control.plane.drain:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_control_plane_drain.sh" \
    "cluster.upgrade.control.plane.apply:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_control_plane_apply.sh" \
    "cluster.upgrade.control.plane.restart:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_control_plane_restart.sh"
}

# 升级 Workers
task::upgrade_workers() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.upgrade.workers:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_workers.sh"
}

# 升级 CNI
task::upgrade_cni() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.upgrade.cni:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_cni.sh"
}

# 升级 Addons
task::upgrade_addons() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.upgrade.addons:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_addons.sh"
}

# 升级状态
task::upgrade_status() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.upgrade.status:${KUBEXM_ROOT}/internal/task/cluster/cluster_upgrade_status.sh"
}

# 完整升级流程
task::upgrade_cluster() {
  local ctx="$1"
  shift
  task::upgrade_precheck "${ctx}" "$@"
  task::upgrade_check_version "${ctx}" "$@"
  task::upgrade_control_plane "${ctx}" "$@"
  task::upgrade_workers "${ctx}" "$@"
  task::upgrade_cni "${ctx}" "$@"
  task::upgrade_addons "${ctx}" "$@"
  task::upgrade_status "${ctx}" "$@"
}

export -f task::upgrade_precheck
export -f task::upgrade_check_version
export -f task::upgrade_control_plane
export -f task::upgrade_workers
export -f task::upgrade_cni
export -f task::upgrade_addons
export -f task::upgrade_status
export -f task::upgrade_cluster
