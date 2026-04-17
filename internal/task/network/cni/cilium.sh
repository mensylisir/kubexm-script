#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CNI Task - cilium
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_cilium_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.dirs.cni.cilium:${KUBEXM_ROOT}/internal/task/common/dirs_cni_cilium.sh"
}

task::render_cilium() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.cni.cilium:${KUBEXM_ROOT}/internal/task/common/render/cni_cilium.sh"
}

task::install_cilium() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.cni.collect.cluster.name:${KUBEXM_ROOT}/internal/task/common/cni/collect_cluster_name.sh" \
    "cluster.install.cni.collect.node.name:${KUBEXM_ROOT}/internal/task/common/cni/collect_node_name.sh" \
    "cluster.install.cni.collect.arch:${KUBEXM_ROOT}/internal/task/common/cni/collect_arch.sh" \
    "cluster.install.cni.collect.version:${KUBEXM_ROOT}/internal/task/common/cni/collect_version.sh" \
    "cluster.install.cni.copy.binaries:${KUBEXM_ROOT}/internal/task/common/cni/copy_binaries.sh" \
    "cluster.install.cni.cilium:${KUBEXM_ROOT}/internal/task/common/cni/cilium.sh"
}

task::delete_cilium() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cni.cilium.delete:${KUBEXM_ROOT}/internal/step/network/cni/cilium_delete.sh"
}

export -f task::collect_cilium_config_dirs
export -f task::render_cilium
export -f task::install_cilium
export -f task::delete_cilium