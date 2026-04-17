#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CNI Task - calico
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_calico_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.cni.calico:${KUBEXM_ROOT}/internal/task/common/config/cni_calico.sh"
}

task::render_calico() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.cni.calico:${KUBEXM_ROOT}/internal/task/common/render/cni_calico.sh"
}

task::install_calico() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.cni.collect.cluster.name:${KUBEXM_ROOT}/internal/task/common/cni/collect_cluster_name.sh" \
    "cluster.install.cni.collect.node.name:${KUBEXM_ROOT}/internal/task/common/cni/collect_node_name.sh" \
    "cluster.install.cni.collect.arch:${KUBEXM_ROOT}/internal/task/common/cni/collect_arch.sh" \
    "cluster.install.cni.collect.version:${KUBEXM_ROOT}/internal/task/common/cni/collect_version.sh" \
    "cluster.install.cni.copy.binaries:${KUBEXM_ROOT}/internal/task/common/cni/copy_binaries.sh" \
    "cluster.install.cni.calico:${KUBEXM_ROOT}/internal/task/common/cni/calico.sh"
}

task::delete_calico() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cni.calico.delete:${KUBEXM_ROOT}/internal/step/network/cni/calico_delete.sh"
}

export -f task::collect_calico_config_dirs
export -f task::render_calico
export -f task::install_calico
export -f task::delete_calico