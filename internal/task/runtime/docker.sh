#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Runtime Task - docker
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_docker_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.runtime.docker:${KUBEXM_ROOT}/internal/task/common/config/runtime_docker.sh"
}

task::render_docker() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.runtime.docker:${KUBEXM_ROOT}/internal/task/common/render/runtime_docker.sh"
}

task::install_docker() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.runtime.docker.collect.cluster.name:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/collect_cluster_name.sh" \
    "cluster.install.runtime.docker.collect.node.name:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/collect_node_name.sh" \
    "cluster.install.runtime.docker.collect.arch:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/collect_arch.sh" \
    "cluster.install.runtime.docker.collect.versions:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/collect_versions.sh" \
    "cluster.install.runtime.docker.collect.paths:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/collect_paths.sh" \
    "cluster.install.runtime.docker.copy.binaries:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/copy_binaries.sh" \
    "cluster.install.runtime.docker.render.configs:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/render_configs.sh" \
    "cluster.install.runtime.docker.systemd:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/systemd.sh"
}

task::delete_docker() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.cleanup.runtime.docker.stop:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/cleanup_stop.sh" \
    "cluster.cleanup.runtime.docker.disable:${KUBEXM_ROOT}/internal/task/kubexm/runtime/docker/cleanup_disable.sh"
}

export -f task::collect_docker_config_dirs
export -f task::render_docker
export -f task::install_docker
export -f task::delete_docker