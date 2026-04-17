#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Domain Normalization
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

#######################################
# Warn for deprecated value mapping
# Arguments:
#   $1 - old value
#   $2 - normalized value
#######################################
domain::warn_deprecated_map() {
  local old_value="${1:-}"
  local normalized_value="${2:-}"

  if [[ -n "${old_value}" && -n "${normalized_value}" && "${old_value}" != "${normalized_value}" ]]; then
    if declare -f log::warn >/dev/null 2>&1; then
      log::warn "检测到已弃用配置值 '${old_value}'，已自动转换为 '${normalized_value}'"
    else
      echo "[WARN] deprecated value '${old_value}' normalized to '${normalized_value}'" >&2
    fi
  fi
}

#######################################
# Normalize kubernetes type
#######################################
domain::normalize_k8s_type() {
  local raw="${1:-}"
  echo "${raw}"
}

#######################################
# Normalize etcd type
#######################################
domain::normalize_etcd_type() {
  local raw="${1:-}"

  case "${raw}" in
    external)
      domain::warn_deprecated_map "external" "exists"
      echo "exists"
      ;;
    *)
      echo "${raw}"
      ;;
  esac
}

#######################################
# Normalize loadbalancer mode
#######################################
domain::normalize_lb_mode() {
  local raw="${1:-}"
  echo "${raw}"
}

#######################################
# Normalize loadbalancer type
#######################################
domain::normalize_lb_type() {
  local raw="${1:-}"

  case "${raw}" in
    existing)
      domain::warn_deprecated_map "existing" "exists"
      echo "exists"
      ;;
    kubexm_kh)
      domain::warn_deprecated_map "kubexm_kh" "kubexm-kh"
      echo "kubexm-kh"
      ;;
    kubexm_kn)
      domain::warn_deprecated_map "kubexm_kn" "kubexm-kn"
      echo "kubexm-kn"
      ;;
    *)
      echo "${raw}"
      ;;
  esac
}

export -f domain::warn_deprecated_map
export -f domain::normalize_k8s_type
export -f domain::normalize_etcd_type
export -f domain::normalize_lb_mode
export -f domain::normalize_lb_type
