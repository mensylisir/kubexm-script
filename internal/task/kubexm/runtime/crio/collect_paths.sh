#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.crio.collect.paths::check() { return 1; }

step::cluster.install.runtime.crio.collect.paths::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local arch containerd_version
  arch="$(context::get "runtime_crio_arch" || true)"
  containerd_version="$(context::get "runtime_crio_containerd_version" || true)"

  local base_dir
  base_dir="${KUBEXM_ROOT}/packages"
  local crio_dir
  crio_dir="${base_dir}/containerd/${containerd_version}/${arch}"

  if [[ ! -d "${crio_dir}" ]]; then
    log::error "CRI-O binaries not found: ${crio_dir}"
    return 1
  fi

  context::set "runtime_crio_base_dir" "${base_dir}"
  context::set "runtime_crio_bin_dir" "${crio_dir}"
}

step::cluster.install.runtime.crio.collect.paths::rollback() { return 0; }

step::cluster.install.runtime.crio.collect.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
