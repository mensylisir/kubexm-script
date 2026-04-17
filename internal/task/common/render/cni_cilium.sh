#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.cni.cilium::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local cni_skip network_plugin
  cni_skip="$(context::get "cni_skip" || echo "false")"
  if [[ "${cni_skip}" == "true" ]]; then
    return 0
  fi
  network_plugin="$(context::get "cni_network_plugin" || true)"
  if [[ "${network_plugin}" != "cilium" ]]; then
    return 0
  fi
  local k8s_version cilium_version first_master_dir
  k8s_version="$(context::get "cni_k8s_version" || true)"
  cilium_version="$(context::get "cni_cilium_version" || true)"
  first_master_dir="$(context::get "cni_first_master_dir" || true)"
  if [[ -z "${first_master_dir}" || -z "${cilium_version}" ]]; then
    return 1
  fi
  local output_file="${first_master_dir}/cilium/${cilium_version}/cilium.yaml"
  if [[ -f "${output_file}" ]]; then
    return 0
  fi
  return 1
}

step::cluster.render.cni.cilium::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"
  source "${KUBEXM_ROOT}/internal/utils/common.sh"

  local cni_skip network_plugin
  cni_skip="$(context::get "cni_skip" || echo "false")"
  if [[ "${cni_skip}" == "true" ]]; then
    return 0
  fi

  network_plugin="$(context::get "cni_network_plugin" || true)"
  if [[ "${network_plugin}" != "cilium" ]]; then
    return 0
  fi

  local k8s_version pod_cidr registry_addr first_master_dir packages_dir
  k8s_version="$(context::get "cni_k8s_version" || true)"
  pod_cidr="$(context::get "cni_pod_cidr" || true)"
  registry_addr="$(context::get "cni_registry_addr" || true)"
  first_master_dir="$(context::get "cni_first_master_dir" || true)"
  packages_dir="$(context::get "cni_packages_dir" || true)"

  local cilium_version output_file helm_dir
  cilium_version=$(versions::get "cilium" "${k8s_version}" || defaults::get_cilium_version)
  output_file="${first_master_dir}/cilium/${cilium_version}/cilium.yaml"
  mkdir -p "$(dirname "${output_file}")"
  helm_dir="${packages_dir}/helm/cilium/${cilium_version}"

  if [[ -d "${helm_dir}" ]]; then
    log::info "  Using downloaded Cilium Helm chart"
    if ! command -v helm &>/dev/null; then
      local arch helm_version helm_bin
      arch="$(utils::get_arch)"
      helm_version=$(versions::get "helm" "${k8s_version}" || defaults::get_helm_version)
      helm_bin="${KUBEXM_ROOT}/packages/helm/${helm_version}/${arch}/helm"
      if [[ -f "${helm_bin}" ]]; then
        chmod +x "${helm_bin}" || true
        mkdir -p "${KUBEXM_ROOT}/bin"
        ln -sf "${helm_bin}" "${KUBEXM_ROOT}/bin/helm"
        export PATH="${KUBEXM_ROOT}/bin:${PATH}"
      else
        log::error "helm not available: ${helm_bin}"
        return 1
      fi
    fi
    if ! helm template cilium "${helm_dir}/cilium" \
      --set image.repository="${registry_addr}/cilium/cilium" \
      --set operator.image.repository="${registry_addr}/cilium/operator" \
      > "${output_file}" 2>/dev/null; then
      log::error "Failed to render Cilium Helm chart from ${helm_dir}/cilium"
      return 1
    fi
    sed -i "s|quay.io/cilium/|${registry_addr}/cilium/|g" "${output_file}"
  elif [[ -f "${KUBEXM_ROOT}/templates/addons/cilium/cilium.yaml.tmpl" ]]; then
    declare -A cilium_vars=(
      [POD_CIDR]="${pod_cidr}"
      [CILIUM_VERSION]="${cilium_version}"
      [REGISTRY]="${registry_addr}"
    )
    template::render "${KUBEXM_ROOT}/templates/addons/cilium/cilium.yaml.tmpl" "${output_file}" cilium_vars
    sed -i "s|quay.io/cilium/|${registry_addr}/cilium/|g" "${output_file}"
  fi

  log::info "  Rendered cilium CNI config"
}

step::cluster.render.cni.cilium::rollback() { return 0; }

step::cluster.render.cni.cilium::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
