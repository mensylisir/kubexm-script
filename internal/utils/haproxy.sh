#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - HAProxy Load Balancer Manager
# ==============================================================================
# 管理Kubernetes集群的HAProxy负载均衡器配置
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 加载依赖
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/template.sh"

# ==============================================================================
# HAProxy负载均衡器管理
# ==============================================================================

#######################################
# 生成HAProxy配置文件
# Arguments:
#   $1 - 输出目录
#   $2 - 后端服务器列表（IP:PORT格式）
#   $3 - 监听端口
#   $4 - SSL端口（可选）
# Returns:
#   0 on success, 1 on failure
#######################################
haproxy::generate_config() {
  local output_dir="$1"
  local backend_servers="$2"
  local listen_port="${3:-$(defaults::get_api_server_port)}"
  local ssl_port="${4:-}"

  log::info "Generating HAProxy configuration..."

  # 准备模板变量
  declare -A haproxy_vars=(
    [BACKEND_SERVERS]="${backend_servers}"
    [LISTEN_PORT]="${listen_port}"
    [SSL_PORT]="${ssl_port}"
    [HAPROXY_VERSION]="2.8.5"
  )

  # 渲染HAProxy配置模板
  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/loadbalancer/haproxy/haproxy.cfg.tmpl"
  local config_file="${output_dir}/haproxy.cfg"

  if ! template::render "${template_file}" "${config_file}" haproxy_vars; then
    log::error "Failed to render HAProxy configuration template"
    return 1
  fi

  log::success "HAProxy configuration generated: ${config_file}"
  return 0
}

#######################################
# 生成HAProxy systemd服务文件
# Arguments:
#   $1 - 输出目录
# Returns:
#   0 on success, 1 on failure
#######################################
haproxy::generate_service() {
  local output_dir="$1"

  log::info "Generating HAProxy systemd service..."

  # 渲染HAProxy服务模板
  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/loadbalancer/haproxy/haproxy.service.tmpl"
  local service_file="${output_dir}/haproxy.service"

  if ! template::render "${template_file}" "${service_file}"; then
    log::error "Failed to render HAProxy service template"
    return 1
  fi

  log::success "HAProxy service generated: ${service_file}"
  return 0
}

export -f haproxy::generate_config
export -f haproxy::generate_service
