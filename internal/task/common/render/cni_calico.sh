#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.cni.calico::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local cni_skip network_plugin
  cni_skip="$(context::get "cni_skip" || echo "false")"
  if [[ "${cni_skip}" == "true" ]]; then
    return 0
  fi
  network_plugin="$(context::get "cni_network_plugin" || true)"
  if [[ "${network_plugin}" != "calico" ]]; then
    return 0
  fi
  local k8s_version calico_version first_master_dir
  k8s_version="$(context::get "cni_k8s_version" || true)"
  calico_version="$(context::get "cni_calico_version" || true)"
  first_master_dir="$(context::get "cni_first_master_dir" || true)"
  if [[ -z "${first_master_dir}" || -z "${calico_version}" ]]; then
    return 1
  fi
  local output_file="${first_master_dir}/calico/${calico_version}/calico.yaml"
  if [[ -f "${output_file}" ]]; then
    return 0
  fi
  return 1
}

step::cluster.render.cni.calico::run() {
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
  if [[ "${network_plugin}" != "calico" ]]; then
    return 0
  fi

  local k8s_version pod_cidr registry_addr first_master_dir packages_dir
  k8s_version="$(context::get "cni_k8s_version" || true)"
  pod_cidr="$(context::get "cni_pod_cidr" || true)"
  registry_addr="$(context::get "cni_registry_addr" || true)"
  first_master_dir="$(context::get "cni_first_master_dir" || true)"
  packages_dir="$(context::get "cni_packages_dir" || true)"

  local calico_version calico_tag output_file source_yaml
  calico_version=$(versions::get "calico" "${k8s_version}" || defaults::get_calico_version)
  calico_tag=$(versions::get_calico_tag "${calico_version}" 2>/dev/null || echo "${calico_version}")
  output_file="${first_master_dir}/calico/${calico_version}/calico.yaml"
  mkdir -p "$(dirname "${output_file}")"
  source_yaml="${packages_dir}/calico/v${calico_version}/calico.yaml"

  if [[ -f "${source_yaml}" ]]; then
    log::info "  Using downloaded Calico manifest from packages/"
    sed -e "s|docker.io/calico/|${registry_addr}/calico/|g" \
        -e "s|quay.io/calico/|${registry_addr}/calico/|g" \
        "${source_yaml}" > "${output_file}"
  elif [[ -f "${KUBEXM_ROOT}/templates/addons/calico/calico.yaml.tmpl" ]]; then
    log::info "  Using Calico template"
    declare -A calico_vars=(
      [POD_CIDR]="${pod_cidr}"
      [CALICO_VERSION]="${calico_tag}"
      [REGISTRY]="${registry_addr}"
    )
    template::render "${KUBEXM_ROOT}/templates/addons/calico/calico.yaml.tmpl" "${output_file}" calico_vars
    sed -i "s|docker.io/calico/|${registry_addr}/calico/|g" "${output_file}"
  else
    log::warn "Calico manifest not found, skipping CNI rendering"
  fi

  log::info "  Rendered calico CNI config"
}

step::cluster.render.cni.calico::rollback() { return 0; }

step::cluster.render.cni.calico::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
