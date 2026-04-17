#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.addon.metrics.server::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local addon_skip
  addon_skip="$(context::get "addon_skip" || echo "false")"
  if [[ "${addon_skip}" == "true" ]]; then
    return 0
  fi
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  if [[ "$(config::get_metrics_server_enabled)" != "true" ]]; then
    return 0
  fi
  local k8s_version registry_addr first_master_dir metrics_version
  k8s_version="$(context::get "addon_k8s_version" || true)"
  registry_addr="$(context::get "addon_registry_addr" || true)"
  first_master_dir="$(context::get "addon_first_master_dir" || true)"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  metrics_version=$(versions::get "metrics-server" "${k8s_version}" || defaults::get_metrics_server_version)
  if [[ -z "${first_master_dir}" ]]; then
    return 1
  fi
  local output_file="${first_master_dir}/metrics-server/${metrics_version}/components.yaml"
  if [[ -f "${output_file}" ]]; then
    return 0
  fi
  return 1
}

step::cluster.render.addon.metrics.server::run() {
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

  if [[ "$(config::get_metrics_server_enabled)" != "true" ]]; then
    return 0
  fi

  local k8s_version registry_addr first_master_dir
  k8s_version="$(context::get "addon_k8s_version" || true)"
  registry_addr="$(context::get "addon_registry_addr" || true)"
  first_master_dir="$(context::get "addon_first_master_dir" || true)"

  local metrics_version output_file
  metrics_version=$(versions::get "metrics-server" "${k8s_version}" || defaults::get_metrics_server_version)
  output_file="${first_master_dir}/metrics-server/${metrics_version}/components.yaml"

  if [[ -d "${KUBEXM_ROOT}/packages/helm/metrics-server" ]]; then
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
    if ! helm template metrics-server "${KUBEXM_ROOT}/packages/helm/metrics-server" \
      --set image.repository="${registry_addr}/metrics-server/metrics-server" \
      --set image.tag="${metrics_version}" \
      > "${output_file}" 2>/dev/null; then
      log::error "Failed to render metrics-server chart"
      return 1
    fi
    log::info "  Rendered metrics-server config"
  fi
}

step::cluster.render.addon.metrics.server::rollback() { return 0; }

step::cluster.render.addon.metrics.server::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
