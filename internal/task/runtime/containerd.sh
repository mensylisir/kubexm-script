#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Runtime Task - containerd
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_containerd_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.runtime.containerd:${KUBEXM_ROOT}/internal/task/common/config/runtime_containerd.sh"
}

task::render_containerd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.runtime.containerd:${KUBEXM_ROOT}/internal/task/common/render/runtime_containerd.sh"
}

task::install_containerd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.runtime.containerd.collect.cluster.name:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/collect_cluster_name.sh" \
    "cluster.install.runtime.containerd.collect.node.name:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/collect_node_name.sh" \
    "cluster.install.runtime.containerd.collect.arch:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/collect_arch.sh" \
    "cluster.install.runtime.containerd.collect.versions:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/collect_versions.sh" \
    "cluster.install.runtime.containerd.collect.paths:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/collect_paths.sh" \
    "cluster.install.runtime.containerd.copy.binaries:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/copy_binaries.sh" \
    "cluster.install.runtime.containerd.render.configs:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/render_configs.sh" \
    "cluster.install.runtime.containerd.systemd:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/systemd.sh"
}

task::delete_containerd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.cleanup.runtime.containerd.stop:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/cleanup_stop.sh" \
    "cluster.cleanup.runtime.containerd.disable:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/cleanup_disable.sh" \
    "cluster.cleanup.runtime.containerd.data:${KUBEXM_ROOT}/internal/task/kubexm/runtime/containerd/cleanup_data.sh"
}

export -f task::collect_containerd_config_dirs
export -f task::render_containerd
export -f task::install_containerd
export -f task::delete_containerd