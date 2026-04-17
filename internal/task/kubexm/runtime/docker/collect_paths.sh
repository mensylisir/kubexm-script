#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.docker.collect.paths::check() { return 1; }

step::cluster.install.runtime.docker.collect.paths::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local cluster_name node_name arch containerd_version
  cluster_name="$(context::get "runtime_docker_cluster_name" || true)"
  node_name="$(context::get "runtime_docker_node_name" || true)"
  arch="$(context::get "runtime_docker_arch" || true)"
  containerd_version="$(context::get "runtime_docker_containerd_version" || true)"

  local base_dir
  base_dir="${KUBEXM_ROOT}/packages"
  local docker_bins_dir
  docker_bins_dir="${base_dir}/containerd/${containerd_version}/${arch}"
  if [[ ! -d "${docker_bins_dir}" ]]; then
    log::error "Docker binaries not found: ${docker_bins_dir}"
    return 1
  fi

  local local_docker_cfg="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/docker/daemon.json"

  context::set "runtime_docker_base_dir" "${base_dir}"
  context::set "runtime_docker_bins_dir" "${docker_bins_dir}"
  context::set "runtime_docker_local_cfg" "${local_docker_cfg}"
}

step::cluster.install.runtime.docker.collect.paths::rollback() { return 0; }

step::cluster.install.runtime.docker.collect.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
