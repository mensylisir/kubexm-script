#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.addon.metrics.server::check() {
  if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    return 0
  fi
  return 1
}

step::cluster.install.addon.metrics.server::run() {
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

  if [[ "$(config::get_metrics_server_enabled)" != "true" ]]; then
    log::info "Metrics-server is disabled, skipping"
    return 0
  fi

  local mode first_master k8s_version kubeconfig
  mode=$(config::get_mode)
  first_master=$(config::get_role_members 'control-plane' | head -n1 | awk '{print $1}')
  k8s_version=$(config::get_kubernetes_version)
  kubeconfig="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

  log::info "Installing metrics-server..."
  local metrics_version
  metrics_version=$(versions::get "metrics-server" "${k8s_version}" || defaults::get_metrics_server_version)
  if [[ "${mode}" == "offline" && -n "${cluster_name}" ]]; then
    local manifest="${KUBEXM_ROOT}/packages/${cluster_name}/${first_master}/metrics-server/${metrics_version}/components.yaml"
    if [[ -f "${manifest}" ]]; then
      if ! kubectl --kubeconfig="${kubeconfig}" apply -f "${manifest}"; then
        log::error "Failed to apply metrics-server manifest: ${manifest}"
        return 1
      fi
    else
      log::error "Metrics-server manifest not found: ${manifest}"
      log::error "Please run 'kubexm download --cluster=${cluster_name}' first"
      return 1
    fi
  else
    if ! kubectl --kubeconfig="${kubeconfig}" apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${metrics_version}/components.yaml"; then
      log::error "Failed to apply metrics-server in online mode"
      return 1
    fi
  fi
}

step::cluster.install.addon.metrics.server::rollback() { return 0; }

step::cluster.install.addon.metrics.server::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
