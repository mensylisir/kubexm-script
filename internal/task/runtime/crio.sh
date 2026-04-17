#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Runtime Task - crio
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_crio_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.runtime.crio:${KUBEXM_ROOT}/internal/task/common/config/runtime_crio.sh"
}

task::render_crio() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.runtime.crio:${KUBEXM_ROOT}/internal/task/common/render/runtime_crio.sh"
}

task::install_crio() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.runtime.crio.collect.cluster.name:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/collect_cluster_name.sh" \
    "cluster.install.runtime.crio.collect.node.name:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/collect_node_name.sh" \
    "cluster.install.runtime.crio.collect.arch:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/collect_arch.sh" \
    "cluster.install.runtime.crio.collect.versions:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/collect_versions.sh" \
    "cluster.install.runtime.crio.collect.paths:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/collect_paths.sh" \
    "cluster.install.runtime.crio.copy.binaries:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/copy_binaries.sh" \
    "cluster.install.runtime.crio.render.configs:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/render_configs.sh" \
    "cluster.install.runtime.crio.systemd:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/systemd.sh"
}

task::delete_crio() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.cleanup.runtime.crio.stop:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/cleanup_stop.sh" \
    "cluster.cleanup.runtime.crio.disable:${KUBEXM_ROOT}/internal/task/kubexm/runtime/crio/cleanup_disable.sh"
}

export -f task::collect_crio_config_dirs
export -f task::render_crio
export -f task::install_crio
export -f task::delete_crio