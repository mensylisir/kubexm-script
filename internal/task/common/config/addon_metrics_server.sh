#!/usr/bin/env bash
set -euo pipefail

step::cluster.config.dirs.addon.metrics.server::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local metrics_enabled first_master k8s_version cluster_dir metrics_version
  metrics_enabled="$(context::get "config_dirs_metrics_enabled" || true)"
  if [[ "${metrics_enabled}" != "true" ]]; then
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
  metrics_version=$(versions::get "metrics-server" "${k8s_version}" || defaults::get_metrics_server_version)
  if [[ -d "${cluster_dir}/${first_master}/metrics-server/${metrics_version}" ]]; then
    return 0  # dir exists, skip
  fi
  return 1  # need to create
}

step::cluster.config.dirs.addon.metrics.server::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local metrics_enabled
  metrics_enabled="$(context::get "config_dirs_metrics_enabled" || true)"
  if [[ "${metrics_enabled}" != "true" ]]; then
    return 0
  fi

  local first_master k8s_version cluster_dir
  first_master="$(context::get "config_dirs_first_master" || true)"
  k8s_version="$(context::get "config_dirs_k8s_version" || true)"
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  if [[ -z "${first_master}" ]]; then
    return 0
  fi

  local metrics_version
  metrics_version=$(versions::get "metrics-server" "${k8s_version}" || defaults::get_metrics_server_version)
  mkdir -p "${cluster_dir}/${first_master}/metrics-server/${metrics_version}"
}

step::cluster.config.dirs.addon.metrics.server::rollback() { return 0; }

step::cluster.config.dirs.addon.metrics.server::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
