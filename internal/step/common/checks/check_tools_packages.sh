#!/usr/bin/env bash
set -euo pipefail

step::check.tools.packages::check() { return 1; }

step::check.tools.packages::run() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  if [[ "${KUBEXM_REQUIRE_PACKAGES:-false}" != "true" ]]; then
    return 0
  fi

  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local k8s_version
  k8s_version=$(config::get_kubernetes_version)
  local k8s_type
  k8s_type=$(config::get_kubernetes_type)
  local etcd_type
  etcd_type=$(config::get_etcd_type)
  local runtime_type
  runtime_type=$(config::get_runtime_type)
  local network_plugin
  network_plugin=$(config::get_network_plugin)
  local lb_enabled
  lb_enabled=$(config::get_loadbalancer_enabled)
  local lb_mode
  lb_mode=$(config::get_loadbalancer_mode)
  local lb_type
  lb_type=$(config::get_loadbalancer_type)
  local arch_list
  arch_list=$(config::get_arch_list)
  arch_list="${arch_list//,/ }"

  local packages_root="${KUBEXM_ROOT}/packages"
  if [[ ! -d "${packages_root}" ]]; then
    echo "missing offline packages root: ${packages_root}" >&2
    return 2
  fi

  source "${KUBEXM_ROOT}/internal/utils/offline/validate_packages.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/image_manager.sh"

  if ! offline::packages::verify "${packages_root}" "${k8s_version}" "${k8s_type}" "${etcd_type}" "${runtime_type}" "${network_plugin}" "${lb_enabled}" "${lb_mode}" "${lb_type}" "${arch_list}"; then
    return 2
  fi
}

step::check.tools.packages::rollback() { return 0; }

step::check.tools.packages::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
