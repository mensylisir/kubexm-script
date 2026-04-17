#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.cni.collect.version::check() { return 1; }

step::cluster.install.cni.collect.version::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"

  local arch
  arch="$(context::get "cni_install_arch" || true)"

  local k8s_version cni_version
  k8s_version=$(config::get_kubernetes_version)
  cni_version=$(versions::get "cni" "${k8s_version}")

  local cni_dir="${KUBEXM_ROOT}/packages/cni-plugins/${cni_version}/${arch}"
  if [[ ! -d "${cni_dir}" ]]; then
    log::error "CNI plugins not found: ${cni_dir}"
    return 1
  fi

  context::set "cni_install_k8s_version" "${k8s_version}"
  context::set "cni_install_version" "${cni_version}"
  context::set "cni_install_dir" "${cni_dir}"
}

step::cluster.install.cni.collect.version::rollback() { return 0; }

step::cluster.install.cni.collect.version::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
