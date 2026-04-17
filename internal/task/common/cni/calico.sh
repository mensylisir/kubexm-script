#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.cni.calico::check() {
  if kubectl get daemonset calico-node -n kube-system &>/dev/null; then
    return 0
  fi
  return 1
}

step::cluster.install.cni.calico::run() {
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

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/cni.sh"

  cni::prepare "${cluster_name}"

  local kubeconfig="${CNI_KUBECONFIG:-/etc/kubernetes/admin.conf}"
  local first_master="${CNI_FIRST_MASTER:-}"
  if [[ -z "${first_master}" ]]; then
    first_master=$(config::get_role_members 'control-plane' | awk '{print $1}')
  fi
  if [[ -z "${first_master}" ]]; then
    log::error "No control-plane nodes found for Calico install"
    return 1
  fi

  local k8s_version calico_version manifest_file
  k8s_version=$(config::get_kubernetes_version)
  calico_version=$(versions::get "calico" "${k8s_version}" || defaults::get_calico_version)
  manifest_file="${KUBEXM_ROOT}/packages/${cluster_name}/${first_master}/calico/${calico_version}/calico.yaml"
  if [[ ! -f "${manifest_file}" ]]; then
    log::error "Calico manifest not found: ${manifest_file}"
    return 1
  fi

  if kubectl --kubeconfig="${kubeconfig}" apply -f "${manifest_file}" >/dev/null 2>&1; then
    log::success "Calico CNI plugin applied"
  else
    log::error "Failed to apply Calico CNI manifest"
    return 1
  fi
}

step::cluster.install.cni.calico::rollback() { return 0; }

step::cluster.install.cni.calico::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
