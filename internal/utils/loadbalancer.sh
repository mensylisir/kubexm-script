#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Load Balancer Render Helper
# ==============================================================================
# 仅负责配置渲染，不执行任何远程操作
# ============================================================================== 

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 加载依赖
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/haproxy.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/nginx.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/keepalived.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/kube-vip.sh"

#######################################
# 生成负载均衡器配置
# Arguments:
#   $1 - 输出目录
#   $2 - 负载均衡器类型 (haproxy|nginx|keepalived|kube-vip)
#   $3... - 类型相关参数
# Returns:
#   0 on success, 1 on failure
#######################################
loadbalancer::generate_config() {
  local output_dir="$1"
  local lb_type="$2"
  shift 2
  local config_params=("$@")

  log::info "Generating ${lb_type} configuration..."

  mkdir -p "${output_dir}"

  case "${lb_type}" in
    haproxy)
      if [[ ${#config_params[@]} -ge 2 ]]; then
        haproxy::generate_config "${output_dir}" "${config_params[0]}" "${config_params[1]}"
      else
        log::error "Insufficient parameters for HAProxy configuration"
        return 1
      fi
      ;;
    nginx)
      if [[ ${#config_params[@]} -ge 2 ]]; then
        nginx::generate_config "${output_dir}" "${config_params[0]}" "${config_params[1]}"
      else
        log::error "Insufficient parameters for Nginx configuration"
        return 1
      fi
      ;;
    keepalived)
      if [[ ${#config_params[@]} -ge 5 ]]; then
        keepalived::generate_config "${output_dir}" "${config_params[0]}" "${config_params[1]}" "${config_params[2]}" "${config_params[3]}" "${config_params[4]}"
      else
        log::error "Insufficient parameters for Keepalived configuration"
        return 1
      fi
      ;;
    kube-vip)
      if [[ ${#config_params[@]} -ge 3 ]]; then
        kube_vip::generate_static_pod "${output_dir}" "${config_params[0]}" "${config_params[1]}" "${config_params[2]}"
      else
        log::error "Insufficient parameters for Kube-VIP configuration"
        return 1
      fi
      ;;
    *)
      log::error "Unknown load balancer type: ${lb_type}"
      return 1
      ;;
  esac

  log::success "${lb_type} configuration generated in: ${output_dir}"
  return 0
}

export -f loadbalancer::generate_config
