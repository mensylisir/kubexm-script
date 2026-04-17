#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.addon.ingress::check() {
  if kubectl get namespace ingress-nginx &>/dev/null; then
    if kubectl get deployment -n ingress-nginx &>/dev/null; then
      return 0
    fi
  fi
  return 1
}

step::cluster.install.addon.ingress::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  if [[ "$(config::get_ingress_enabled)" != "true" ]]; then
    log::info "Ingress is disabled, skipping"
    return 0
  fi

  local mode first_master k8s_version kubeconfig
  mode=$(config::get_mode)
  first_master=$(config::get_role_members 'control-plane' | head -n1 | awk '{print $1}')
  k8s_version=$(config::get_kubernetes_version)
  kubeconfig="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

  log::info "Installing ingress controller..."
  local ingress_type ingress_version
  ingress_type=$(config::get_ingress_type)
  ingress_version=$(versions::get "ingress-nginx" "${k8s_version}" || defaults::get_ingress_nginx_version)
  if [[ "${mode}" == "offline" && -n "${cluster_name}" ]]; then
    local manifest="${KUBEXM_ROOT}/packages/${cluster_name}/${first_master}/ingress-${ingress_type}/${ingress_version}/deploy.yaml"
    if [[ -f "${manifest}" ]]; then
      if ! kubectl --kubeconfig="${kubeconfig}" apply -f "${manifest}"; then
        log::error "Failed to apply ingress controller manifest: ${manifest}"
        return 1
      fi
    else
      log::error "Ingress controller manifest not found: ${manifest}"
      log::error "Please run 'kubexm download --cluster=${cluster_name}' first"
      return 1
    fi
  else
    if [[ "${ingress_type}" == "traefik" ]]; then
      if ! kubectl --kubeconfig="${kubeconfig}" apply -f "https://raw.githubusercontent.com/traefik/traefik/v${ingress_version}/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml"; then
        log::error "Failed to apply traefik ingress CRD definition"
        return 1
      fi
    else
      if ! kubectl --kubeconfig="${kubeconfig}" apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${ingress_version}/deploy/static/provider/cloud/deploy.yaml"; then
        log::error "Failed to apply ingress-nginx manifest"
        return 1
      fi
    fi
  fi
}

step::cluster.install.addon.ingress::rollback() { return 0; }

step::cluster.install.addon.ingress::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
