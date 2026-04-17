#!/usr/bin/env bash
set -euo pipefail

step::manifests.collect.system.packages::check() { return 1; }

step::manifests.collect.system.packages::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local runtime cni lb_type lb_mode k8s_type lb_enabled
  runtime="$(context::get "manifests_runtime" || true)"
  cni="$(context::get "manifests_cni" || true)"
  lb_type="$(context::get "manifests_lb_type" || true)"
  lb_mode="$(context::get "manifests_lb_mode" || true)"
  k8s_type="$(context::get "manifests_k8s_type" || true)"
  lb_enabled="$(context::get "manifests_lb_enabled" || true)"

  local has_ha="false"
  if [[ "$lb_enabled" == "true" && ("$lb_mode" == "external" || "$lb_mode" == "kube-vip" || "$lb_mode" == "internal" || "$lb_mode" == "exists") ]]; then
    has_ha="true"
  fi

  local install_ha_packages="$has_ha"
  if [[ "$lb_mode" == "exists" ]]; then
    install_ha_packages="false"
  fi

  local rpm_packages deb_packages
  rpm_packages=($(defaults::get_system_packages "centos7" "$runtime" "$cni" "$lb_type" "false" "$install_ha_packages"))
  deb_packages=($(defaults::get_system_packages "ubuntu2204" "$runtime" "$cni" "$lb_type" "false" "$install_ha_packages"))

  context::set "manifests_system_packages_rpm" "${rpm_packages[*]}"
  context::set "manifests_system_packages_deb" "${deb_packages[*]}"
  context::set "manifests_system_packages_has_ha" "${has_ha}"
  context::set "manifests_system_packages_install_ha" "${install_ha_packages}"
  context::set "manifests_system_packages_lb_type" "${lb_type}"
  context::set "manifests_system_packages_lb_mode" "${lb_mode}"
  context::set "manifests_system_packages_k8s_type" "${k8s_type}"
}

step::manifests.collect.system.packages::rollback() { return 0; }

step::manifests.collect.system.packages::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
