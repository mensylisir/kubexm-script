#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Domain Strategy Rules
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

#######################################
# Build strategy id from k8s+etcd
#######################################
domain::get_strategy_id() {
  local k8s_type="${1:-}"
  local etcd_type="${2:-}"

  k8s_type="$(domain::normalize_k8s_type "${k8s_type}")"
  etcd_type="$(domain::normalize_etcd_type "${etcd_type}")"

  echo "${k8s_type}-${etcd_type}"
}

#######################################
# Check strategy validity against main router
# Supported combinations:
#   kubeadm-kubeadm: K8s via kubeadm, etcd via kubeadm (stacked)
#   kubeadm-kubexm:  K8s via kubeadm, etcd via kubexm binary (external)
#   kubeadm-exists:  K8s via kubeadm, etcd already exists
#   kubexm-kubeadm:  K8s via kubexm binary, etcd via kubeadm (hybrid)
#   kubexm-kubexm:   K8s via kubexm binary, etcd via kubexm binary
#   kubexm-exists:   K8s via kubexm binary, etcd already exists
#######################################
domain::is_valid_strategy() {
  local strategy
  strategy="$(domain::get_strategy_id "${1:-}" "${2:-}")"

  case "${strategy}" in
    kubeadm-kubeadm|kubeadm-kubexm|kubeadm-exists|kubexm-kubeadm|kubexm-kubexm|kubexm-exists)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

#######################################
# Validate loadbalancer combination
#######################################
domain::validate_lb_combination() {
  local lb_enabled="${1:-false}"
  local lb_mode="${2:-}"
  local lb_type="${3:-}"
  local _k8s_type="${4:-}"

  lb_mode="$(domain::normalize_lb_mode "${lb_mode}")"
  lb_type="$(domain::normalize_lb_type "${lb_type}")"

  if [[ "${lb_enabled}" != "true" ]]; then
    return 0
  fi

  if ! domain::is_valid_lb_mode "${lb_mode}"; then
    return 1
  fi

  if ! domain::is_valid_lb_type_for_mode "${lb_mode}" "${lb_type}"; then
    return 1
  fi

  return 0
}

#######################################
# Validate complete deployment combination
#######################################
domain::validate_cluster_combination() {
  local k8s_type="${1:-}"
  local etcd_type="${2:-}"
  local masters_count="${3:-1}"
  local lb_enabled="${4:-false}"
  local lb_mode="${5:-}"
  local lb_type="${6:-}"

  k8s_type="$(domain::normalize_k8s_type "${k8s_type}")"
  etcd_type="$(domain::normalize_etcd_type "${etcd_type}")"

  domain::is_valid_k8s_type "${k8s_type}" || return 1
  domain::is_valid_etcd_type "${etcd_type}" || return 1

  domain::is_valid_strategy "${k8s_type}" "${etcd_type}" || return 1

  # kubexm+kubeadm 组合不合法：kubeadm etcd 堆叠需要 kubeadm 安装 K8s
  # kubexm 二进制部署不会调用 kubeadm init，因此 etcd 不会被安装
  if [[ "${k8s_type}" == "kubexm" ]] && [[ "${etcd_type}" == "kubeadm" ]]; then
    return 1
  fi

  # Single-node cluster with LB enabled: only allowed for internal mode (local LB proxy)
  # External/Kube-Vip/Exists modes don't make sense for single-node
  if [[ "${masters_count}" -eq 1 && "${lb_enabled}" == "true" && "${lb_mode}" != "internal" ]]; then
    return 1
  fi

  domain::validate_lb_combination "${lb_enabled}" "${lb_mode}" "${lb_type}" "${k8s_type}" || return 1

  return 0
}

export -f domain::get_strategy_id
export -f domain::is_valid_strategy
export -f domain::validate_lb_combination
export -f domain::validate_cluster_combination
