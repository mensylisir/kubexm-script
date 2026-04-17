#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.containerd.collect.paths::check() { return 1; }

step::cluster.install.runtime.containerd.collect.paths::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local cluster_name node_name arch containerd_version
  cluster_name="$(context::get "runtime_containerd_cluster_name" || true)"
  node_name="$(context::get "runtime_containerd_node_name" || true)"
  arch="$(context::get "runtime_containerd_arch" || true)"
  containerd_version="$(context::get "runtime_containerd_containerd_version" || true)"

  local base_dir
  base_dir="${KUBEXM_ROOT}/packages"
  local cdir
  cdir="${base_dir}/containerd/${containerd_version}/${arch}"
  if [[ ! -d "${cdir}" ]]; then
    log::error "Containerd binaries not found: ${cdir}"
    return 1
  fi

  local local_cfg="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/containerd/config.toml"

  context::set "runtime_containerd_base_dir" "${base_dir}"
  context::set "runtime_containerd_bin_dir" "${cdir}"
  context::set "runtime_containerd_local_cfg" "${local_cfg}"
}

step::cluster.install.runtime.containerd.collect.paths::rollback() { return 0; }

step::cluster.install.runtime.containerd.collect.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
