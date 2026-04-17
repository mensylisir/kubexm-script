#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# KubeXM Script - Step Targets Helper Library
# ==============================================================================
# 提供通用的 targets() 函数实现，供所有 Step 使用
# 解决 collect 模式中 targets() 重复定义的问题
# ==============================================================================

# 配置依赖：统一在文件顶部加载，避免每个函数重复 source
source "${KUBEXM_ROOT}/internal/config/config.sh"

# ==============================================================================
# Get target IPs for given roles
# Usage: targets::for_roles "control-plane" "worker"
# Returns: space-separated list of IP addresses
# ==============================================================================
targets::for_roles() {
  local roles=("$@")

  local nodes=""
  for role in "${roles[@]}"; do
    nodes="${nodes} $(config::get_role_members "${role}")"
  done
  nodes=$(echo "${nodes}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

  local out=""
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}

# ==============================================================================
# Get target IPs for a single role (deduplicated)
# Usage: targets::for_role "control-plane"
# Returns: space-separated list of IP addresses
# ==============================================================================
targets::for_role() {
  local role="$1"
  targets::for_roles "${role}"
}

# ==============================================================================
# Standard collect targets: control-plane + worker
# This is the most common pattern for collect steps
# Usage: targets::for_standard_collect
# Returns: space-separated list of IP addresses
# ==============================================================================
targets::for_standard_collect() {
  targets::for_roles "control-plane" "worker"
}

# ==============================================================================
# All cluster roles: control-plane + worker + etcd
# Usage: targets::for_all_roles
# Returns: space-separated list of IP addresses
# ==============================================================================
targets::for_all_roles() {
  targets::for_roles "control-plane" "worker" "etcd"
}

# ==============================================================================
# All hosts from host.yaml
# Usage: targets::for_all_hosts
# Returns: space-separated list of IP addresses
# ==============================================================================
targets::for_all_hosts() {
  local nodes out=""
  nodes=$(config::get_all_host_names)
  local node node_ip
  for node in ${nodes}; do
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}

# ==============================================================================
# Worker nodes only
# Usage: targets::for_workers
# Returns: space-separated list of IP addresses
# ==============================================================================
targets::for_workers() {
  targets::for_role "worker"
}

# ==============================================================================
# All nodes of a role except the first one
# Usage: targets::for_role_excluding_first "control-plane"
# Returns: space-separated list of IP addresses (excludes first node)
# ==============================================================================
targets::for_role_excluding_first() {
  local role="$1"
  local nodes first
  nodes=$(config::get_role_members "${role}")
  first=$(echo "${nodes}" | awk '{print $1}')

  local out=""
  for node in ${nodes}; do
    [[ -z "${node}" || "${node}" == "${first}" ]] && continue
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}

# ==============================================================================
# etcd nodes only
# Usage: targets::for_etcd
# Returns: space-separated list of IP addresses
# ==============================================================================
targets::for_etcd() {
  targets::for_role "etcd"
}

# ==============================================================================
# etcd nodes with fallback to control-plane (for kubeadm stacked etcd)
# Usage: targets::for_etcd_with_fallback
# Returns: space-separated list of IP addresses
# ==============================================================================
targets::for_etcd_with_fallback() {
  local etcd_nodes out=""
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane')
  local node node_ip
  for node in ${etcd_nodes}; do
    [[ -z "${node}" ]] && continue
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}

# ==============================================================================
# Export functions
# ==============================================================================
export -f targets::for_roles
export -f targets::for_role
export -f targets::for_standard_collect
export -f targets::for_all_roles
export -f targets::for_all_hosts
export -f targets::for_workers
export -f targets::for_role_excluding_first
export -f targets::for_etcd
export -f targets::for_etcd_with_fallback
