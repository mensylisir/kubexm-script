#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Keepalived Manager
# ==============================================================================
# 管理Kubernetes集群的Keepalived高可用配置
# ============================================================================== 

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 加载依赖
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/template.sh"

# ==============================================================================
# Keepalived管理（渲染专用，不执行远程操作）
# ==============================================================================

#######################################
# 生成Keepalived配置文件
# Arguments:
#   $1 - 输出目录
#   $2 - 虚拟IP地址
#   $3 - 接口名称
#   $4 - 节点角色（MASTER或BACKUP）
#   $5 - 优先级
#   $6 - 认证密码
# Returns:
#   0 on success, 1 on failure
#######################################
keepalived::generate_config() {
  local output_dir="$1"
  local vip="$2"
  local interface="$3"
  local state="$4"
  local priority="$5"
  local auth_pass="$6"

  log::info "Generating Keepalived configuration..."

  # 准备模板变量
  declare -A keepalived_vars=(
    [VIP]="${vip}"
    [INTERFACE]="${interface}"
    [STATE]="${state}"
    [PRIORITY]="${priority}"
    [AUTH_PASS]="${auth_pass}"
    [KEEPALIVED_VERSION]="3.3.1"
  )

  # 渲染Keepalived配置模板
  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/loadbalancer/keepalived/keepalived.conf.tmpl"
  local config_file="${output_dir}/keepalived.conf"

  if ! template::render "${template_file}" "${config_file}" keepalived_vars; then
    log::error "Failed to render Keepalived configuration template"
    return 1
  fi

  log::success "Keepalived configuration generated: ${config_file}"
  return 0
}

#######################################
# 生成Keepalived systemd服务文件
# Arguments:
#   $1 - 输出目录
# Returns:
#   0 on success, 1 on failure
#######################################
keepalived::generate_service() {
  local output_dir="$1"

  log::info "Generating Keepalived systemd service..."

  # 渲染Keepalived服务模板
  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/loadbalancer/keepalived/keepalived.service.tmpl"
  local service_file="${output_dir}/keepalived.service"

  if ! template::render "${template_file}" "${service_file}"; then
    log::error "Failed to render Keepalived service template"
    return 1
  fi

  log::success "Keepalived service generated: ${service_file}"
  return 0
}

#######################################
# 生成Keepalived检测脚本
# Arguments:
#   $1 - 输出目录
#   $2 - 服务名称
# Returns:
#   0 on success, 1 on failure
#######################################
keepalived::generate_check_script() {
  local output_dir="$1"
  local service_name="${2:-haproxy}"

  log::info "Generating Keepalived check script for ${service_name}..."

  # 渲染检测脚本模板
  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/loadbalancer/keepalived/check_${service_name}.sh.tmpl"
  local script_file="${output_dir}/check_${service_name}.sh"

  if ! template::render "${template_file}" "${script_file}"; then
    log::error "Failed to render Keepalived check script template"
    return 1
  fi

  chmod +x "${script_file}"
  log::success "Keepalived check script generated: ${script_file}"
  return 0
}

export -f keepalived::generate_config
export -f keepalived::generate_service
export -f keepalived::generate_check_script
