#!/usr/bin/env bash
set -euo pipefail

step::cluster.config.dirs.cni.calico::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local network_plugin first_master k8s_version cluster_dir cni_version
  network_plugin="$(context::get "config_dirs_network_plugin" || true)"
  if [[ "${network_plugin}" != "calico" ]]; then
    return 0
  fi
  first_master="$(context::get "config_dirs_first_master" || true)"
  k8s_version="$(context::get "config_dirs_k8s_version" || true)"
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  if [[ -z "${first_master}" ]]; then
    return 1
  fi
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  cni_version=$(versions::get "calico" "${k8s_version}" || defaults::get_calico_version)
  if [[ -d "${cluster_dir}/${first_master}/calico/${cni_version}" ]]; then
    return 0  # dir exists, skip
  fi
  return 1  # need to create
}

step::cluster.config.dirs.cni.calico::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local network_plugin
  network_plugin="$(context::get "config_dirs_network_plugin" || true)"
  if [[ "${network_plugin}" != "calico" ]]; then
    return 0
  fi

  local first_master k8s_version cluster_dir
  first_master="$(context::get "config_dirs_first_master" || true)"
  k8s_version="$(context::get "config_dirs_k8s_version" || true)"
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  if [[ -z "${first_master}" ]]; then
    return 0
  fi

  local cni_version
  cni_version=$(versions::get "calico" "${k8s_version}" || defaults::get_calico_version)
  mkdir -p "${cluster_dir}/${first_master}/calico/${cni_version}"
}

step::cluster.config.dirs.cni.calico::rollback() { return 0; }

step::cluster.config.dirs.cni.calico::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
