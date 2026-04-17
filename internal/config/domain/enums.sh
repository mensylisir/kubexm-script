#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Domain Enums
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

readonly DOMAIN_K8S_TYPES=("kubeadm" "kubexm")
readonly DOMAIN_ETCD_TYPES=("kubeadm" "kubexm" "exists")
readonly DOMAIN_LB_MODES=("internal" "external" "kube-vip" "exists")

readonly DOMAIN_LB_TYPES_INTERNAL=("haproxy" "nginx")
readonly DOMAIN_LB_TYPES_EXTERNAL=("kubexm-kh" "kubexm-kn")

#######################################
# Check if value exists in array
# Arguments:
#   $1 - value
#   $2 - array variable name
#######################################
domain::is_in_array() {
  local value="${1:-}"
  local array_name="${2:-}"

  if [[ -z "${array_name}" ]]; then
    return 1
  fi

  local -n arr_ref="${array_name}"
  local item
  for item in "${arr_ref[@]}"; do
    if [[ "${item}" == "${value}" ]]; then
      return 0
    fi
  done
  return 1
}

#######################################
# Validate kubernetes type
#######################################
domain::is_valid_k8s_type() {
  local value="${1:-}"
  domain::is_in_array "${value}" "DOMAIN_K8S_TYPES"
}

#######################################
# Validate etcd type
#######################################
domain::is_valid_etcd_type() {
  local value="${1:-}"
  domain::is_in_array "${value}" "DOMAIN_ETCD_TYPES"
}

#######################################
# Validate loadbalancer mode
#######################################
domain::is_valid_lb_mode() {
  local value="${1:-}"
  domain::is_in_array "${value}" "DOMAIN_LB_MODES"
}

#######################################
# Validate loadbalancer type under mode
#######################################
domain::is_valid_lb_type_for_mode() {
  local mode="${1:-}"
  local lb_type="${2:-}"

  case "${mode}" in
    internal)
      domain::is_in_array "${lb_type}" "DOMAIN_LB_TYPES_INTERNAL"
      ;;
    external)
      domain::is_in_array "${lb_type}" "DOMAIN_LB_TYPES_EXTERNAL"
      ;;
    kube-vip)
      [[ -z "${lb_type}" || "${lb_type}" == "kube-vip" ]]
      ;;
    exists)
      [[ -z "${lb_type}" || "${lb_type}" == "exists" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

export -f domain::is_in_array
export -f domain::is_valid_k8s_type
export -f domain::is_valid_etcd_type
export -f domain::is_valid_lb_mode
export -f domain::is_valid_lb_type_for_mode
