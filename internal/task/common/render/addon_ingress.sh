#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.addon.ingress::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local addon_skip
  addon_skip="$(context::get "addon_skip" || echo "false")"
  if [[ "${addon_skip}" == "true" ]]; then
    return 0
  fi
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  if [[ "$(config::get_ingress_enabled)" != "true" ]]; then
    return 0
  fi
  local k8s_version registry_addr first_master_dir ingress_type ingress_version
  k8s_version="$(context::get "addon_k8s_version" || true)"
  registry_addr="$(context::get "addon_registry_addr" || true)"
  first_master_dir="$(context::get "addon_first_master_dir" || true)"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  ingress_type=$(config::get_ingress_type)
  ingress_version=$(versions::get "ingress-nginx" "${k8s_version}" || defaults::get_ingress_nginx_version)
  if [[ -z "${first_master_dir}" ]]; then
    return 1
  fi
  local output_file="${first_master_dir}/ingress-${ingress_type}/${ingress_version}/deploy.yaml"
  if [[ -f "${output_file}" ]]; then
    return 0
  fi
  return 1
}

step::cluster.render.addon.ingress::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/common.sh"

  local addon_skip
  addon_skip="$(context::get "addon_skip" || echo "false")"
  if [[ "${addon_skip}" == "true" ]]; then
    return 0
  fi

  if [[ "$(config::get_ingress_enabled)" != "true" ]]; then
    return 0
  fi

  local k8s_version registry_addr first_master_dir
  k8s_version="$(context::get "addon_k8s_version" || true)"
  registry_addr="$(context::get "addon_registry_addr" || true)"
  first_master_dir="$(context::get "addon_first_master_dir" || true)"

  local ingress_type ingress_version output_file
  ingress_type=$(config::get_ingress_type)
  ingress_version=$(versions::get "ingress-nginx" "${k8s_version}" || defaults::get_ingress_nginx_version)
  output_file="${first_master_dir}/ingress-${ingress_type}/${ingress_version}/deploy.yaml"

  if [[ -d "${KUBEXM_ROOT}/packages/helm/ingress-nginx" ]] && [[ "${ingress_type}" == "nginx" ]]; then
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
    if ! helm template ingress-nginx "${KUBEXM_ROOT}/packages/helm/ingress-nginx" \
      --set controller.image.registry="${registry_addr}" \
      > "${output_file}" 2>/dev/null; then
      log::error "Failed to render ingress-nginx chart"
      return 1
    fi
    log::info "  Rendered ingress-nginx config"
  fi
}

step::cluster.render.addon.ingress::rollback() { return 0; }

step::cluster.render.addon.ingress::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
