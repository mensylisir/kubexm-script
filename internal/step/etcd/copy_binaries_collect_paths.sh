#!/usr/bin/env bash
set -euo pipefail

step::etcd.copy.binaries.collect.paths::check() { return 1; }

step::etcd.copy.binaries.collect.paths::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"

  local arch
  arch="$(context::get "etcd_binaries_arch" || true)"

  local k8s_version etcd_version
  k8s_version=$(config::get_kubernetes_version)
  etcd_version=$(versions::get "etcd" "${k8s_version}")

  local etcd_bin_dir
  etcd_bin_dir="${KUBEXM_ROOT}/packages/etcd/${etcd_version}/${arch}"
  if [[ ! -d "${etcd_bin_dir}" ]]; then
    log::error "Missing etcd binaries: ${etcd_bin_dir}"
    return 1
  fi

  context::set "etcd_binaries_version" "${etcd_version}"
  context::set "etcd_binaries_dir" "${etcd_bin_dir}"
}

step::etcd.copy.binaries.collect.paths::rollback() { return 0; }

step::etcd.copy.binaries.collect.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
