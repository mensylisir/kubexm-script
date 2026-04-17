#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CNI Task - flannel
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_flannel_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.cni.flannel:${KUBEXM_ROOT}/internal/task/common/config/cni_flannel.sh"
}

task::render_flannel() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.cni.flannel:${KUBEXM_ROOT}/internal/task/common/render/cni_flannel.sh"
}

task::install_flannel() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.cni.collect.cluster.name:${KUBEXM_ROOT}/internal/task/common/cni/collect_cluster_name.sh" \
    "cluster.install.cni.collect.node.name:${KUBEXM_ROOT}/internal/task/common/cni/collect_node_name.sh" \
    "cluster.install.cni.collect.arch:${KUBEXM_ROOT}/internal/task/common/cni/collect_arch.sh" \
    "cluster.install.cni.collect.version:${KUBEXM_ROOT}/internal/task/common/cni/collect_version.sh" \
    "cluster.install.cni.copy.binaries:${KUBEXM_ROOT}/internal/task/common/cni/copy_binaries.sh" \
    "cluster.install.cni.flannel:${KUBEXM_ROOT}/internal/task/common/cni/flannel.sh"
}

task::delete_flannel() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cni.flannel.delete:${KUBEXM_ROOT}/internal/step/network/cni/flannel_delete.sh"
}

export -f task::collect_flannel_config_dirs
export -f task::render_flannel
export -f task::install_flannel
export -f task::delete_flannel