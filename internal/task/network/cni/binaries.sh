#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CNI Task - common binaries
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_cni_binaries() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.cni.collect.cluster.name:${KUBEXM_ROOT}/internal/task/common/install_cni_collect_cluster_name.sh" \
    "cluster.install.cni.collect.node.name:${KUBEXM_ROOT}/internal/task/common/install_cni_collect_node_name.sh" \
    "cluster.install.cni.collect.arch:${KUBEXM_ROOT}/internal/task/common/install_cni_collect_arch.sh" \
    "cluster.install.cni.collect.version:${KUBEXM_ROOT}/internal/task/common/install_cni_collect_version.sh" \
    "cluster.install.cni.copy.binaries:${KUBEXM_ROOT}/internal/task/common/install_cni_copy_binaries.sh"
}

export -f task::install_cni_binaries