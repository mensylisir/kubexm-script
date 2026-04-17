#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.cni.flannel::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local cni_skip network_plugin
  cni_skip="$(context::get "cni_skip" || echo "false")"
  if [[ "${cni_skip}" == "true" ]]; then
    return 0
  fi
  network_plugin="$(context::get "cni_network_plugin" || true)"
  if [[ "${network_plugin}" != "flannel" ]]; then
    return 0
  fi
  local k8s_version flannel_version first_master_dir
  k8s_version="$(context::get "cni_k8s_version" || true)"
  flannel_version="$(context::get "cni_flannel_version" || true)"
  first_master_dir="$(context::get "cni_first_master_dir" || true)"
  if [[ -z "${first_master_dir}" || -z "${flannel_version}" ]]; then
    return 1
  fi
  local output_file="${first_master_dir}/flannel/${flannel_version}/kube-flannel.yml"
  if [[ -f "${output_file}" ]]; then
    return 0
  fi
  return 1
}

step::cluster.render.cni.flannel::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local cni_skip network_plugin
  cni_skip="$(context::get "cni_skip" || echo "false")"
  if [[ "${cni_skip}" == "true" ]]; then
    return 0
  fi

  network_plugin="$(context::get "cni_network_plugin" || true)"
  if [[ "${network_plugin}" != "flannel" ]]; then
    return 0
  fi

  local k8s_version pod_cidr registry_addr first_master_dir packages_dir
  k8s_version="$(context::get "cni_k8s_version" || true)"
  pod_cidr="$(context::get "cni_pod_cidr" || true)"
  registry_addr="$(context::get "cni_registry_addr" || true)"
  first_master_dir="$(context::get "cni_first_master_dir" || true)"
  packages_dir="$(context::get "cni_packages_dir" || true)"

  local flannel_version output_file source_yaml
  flannel_version=$(versions::get "flannel" "${k8s_version}" || defaults::get_flannel_version)
  output_file="${first_master_dir}/flannel/${flannel_version}/kube-flannel.yml"
  mkdir -p "$(dirname "${output_file}")"
  source_yaml="${packages_dir}/flannel/v${flannel_version}/kube-flannel.yml"
  if [[ ! -f "${source_yaml}" ]]; then
    source_yaml="${packages_dir}/flannel/v${flannel_version}/kube-flannel.yaml"
  fi

  if [[ -f "${source_yaml}" ]]; then
    log::info "  Using downloaded Flannel manifest from packages/"
    sed -e "s|docker.io/flannel/|${registry_addr}/flannel/|g" \
        -e "s|ghcr.io/flannel-io/|${registry_addr}/flannel-io/|g" \
        "${source_yaml}" > "${output_file}"
  elif [[ -f "${KUBEXM_ROOT}/templates/addons/flannel/flannel.yaml.tmpl" ]]; then
    declare -A flannel_vars=(
      [POD_CIDR]="${pod_cidr}"
      [FLANNEL_VERSION]="${flannel_version}"
      [REGISTRY]="${registry_addr}"
    )
    template::render "${KUBEXM_ROOT}/templates/addons/flannel/flannel.yaml.tmpl" "${output_file}" flannel_vars
    sed -i "s|docker.io/flannel/|${registry_addr}/flannel/|g" "${output_file}"
  fi

  log::info "  Rendered flannel CNI config"
}

step::cluster.render.cni.flannel::rollback() { return 0; }

step::cluster.render.cni.flannel::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
