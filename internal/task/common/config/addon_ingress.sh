#!/usr/bin/env bash
set -euo pipefail

step::cluster.config.dirs.addon.ingress::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local ingress_enabled first_master k8s_version cluster_dir ingress_type ingress_version
  ingress_enabled="$(context::get "config_dirs_ingress_enabled" || true)"
  if [[ "${ingress_enabled}" != "true" ]]; then
    return 0
  fi
  first_master="$(context::get "config_dirs_first_master" || true)"
  k8s_version="$(context::get "config_dirs_k8s_version" || true)"
  ingress_type="$(context::get "config_dirs_ingress_type" || true)"
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  if [[ -z "${first_master}" ]]; then
    return 1
  fi
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  ingress_version=$(versions::get "ingress-nginx" "${k8s_version}" || defaults::get_ingress_nginx_version)
  if [[ -d "${cluster_dir}/${first_master}/ingress-${ingress_type}/${ingress_version}" ]]; then
    return 0  # dir exists, skip
  fi
  return 1  # need to create
}

step::cluster.config.dirs.addon.ingress::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local ingress_enabled
  ingress_enabled="$(context::get "config_dirs_ingress_enabled" || true)"
  if [[ "${ingress_enabled}" != "true" ]]; then
    return 0
  fi

  local first_master k8s_version cluster_dir ingress_type
  first_master="$(context::get "config_dirs_first_master" || true)"
  k8s_version="$(context::get "config_dirs_k8s_version" || true)"
  ingress_type="$(context::get "config_dirs_ingress_type" || true)"
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  if [[ -z "${first_master}" ]]; then
    return 0
  fi

  local ingress_version
  ingress_version=$(versions::get "ingress-nginx" "${k8s_version}" || defaults::get_ingress_nginx_version)
  mkdir -p "${cluster_dir}/${first_master}/ingress-${ingress_type}/${ingress_version}"
}

step::cluster.config.dirs.addon.ingress::rollback() { return 0; }

step::cluster.config.dirs.addon.ingress::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
