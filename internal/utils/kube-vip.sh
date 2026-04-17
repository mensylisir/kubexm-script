#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Kube-VIP Manager
# ==============================================================================
# 管理Kubernetes集群的Kube-VIP负载均衡器配置
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
source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/template.sh"

# ==============================================================================
# Kube-VIP管理（渲染专用，不执行远程操作）
# ==============================================================================

#######################################
# 生成Kube-VIP静态Pod配置
# Arguments:
#   $1 - 输出目录
#   $2 - 虚拟IP地址
#   $3 - 节点IP
#   $4 - 节点名称
#   $5 - VIP CIDR
# Returns:
#   0 on success, 1 on failure
#######################################
kube_vip::generate_static_pod() {
  local output_dir="$1"
  local vip="$2"
  local node_ip="$3"
  local node_name="$4"
  local vip_cidr="${5:-}"

  log::info "Generating Kube-VIP static pod configuration..."

  # 准备模板变量（从 versions.sh 动态获取版本）
  local k8s_version
  k8s_version=$(config::get_kubernetes_version 2>/dev/null || defaults::get_kubernetes_version)
  local kube_vip_version
  kube_vip_version=$(versions::get "kube-vip" "${k8s_version}" 2>/dev/null || echo "v0.8.0")

  declare -A kube_vip_vars=(
    [VIP]="${vip}"
    [NODE_IP]="${node_ip}"
    [NODE_NAME]="${node_name}"
    [VIP_CIDR]="${vip_cidr}"
    [KUBE_VIP_VERSION]="${kube_vip_version}"
  )

  # 渲染Kube-VIP静态Pod配置模板
  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/loadbalancer/kube-vip/kube-vip-pod.yaml.tmpl"
  local pod_file="${output_dir}/kube-vip-pod.yaml"

  if ! template::render "${template_file}" "${pod_file}" kube_vip_vars; then
    log::error "Failed to render Kube-VIP static pod configuration template"
    return 1
  fi

  log::success "Kube-VIP static pod configuration generated: ${pod_file}"
  return 0
}

#######################################
# 生成Kube-VIP DaemonSet配置
# Arguments:
#   $1 - 输出目录
#   $2 - 虚拟IP地址
#   $3 - 镜像仓库（可选）
# Returns:
#   0 on success, 1 on failure
#######################################
kube_vip::generate_daemonset() {
  local output_dir="$1"
  local vip="$2"
  local image_registry="${3:-}"

  log::info "Generating Kube-VIP DaemonSet configuration..."

  # 准备模板变量（从 versions.sh 动态获取版本）
  local k8s_version
  k8s_version=$(config::get_kubernetes_version 2>/dev/null || defaults::get_kubernetes_version)
  local kube_vip_version
  kube_vip_version=$(versions::get "kube-vip" "${k8s_version}" 2>/dev/null || echo "v0.8.0")

  declare -A kube_vip_vars=(
    [VIP]="${vip}"
    [IMAGE_REGISTRY]="${image_registry}"
    [KUBE_VIP_VERSION]="${kube_vip_version}"
  )

  # 渲染Kube-VIP DaemonSet配置模板
  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/loadbalancer/kube-vip/kube-vip-ds.yaml.tmpl"
  local ds_file="${output_dir}/kube-vip-ds.yaml"

  if ! template::render "${template_file}" "${ds_file}" kube_vip_vars; then
    log::error "Failed to render Kube-VIP DaemonSet configuration template"
    return 1
  fi

  log::success "Kube-VIP DaemonSet configuration generated: ${ds_file}"
  return 0
}

export -f kube_vip::generate_static_pod
export -f kube_vip::generate_daemonset
