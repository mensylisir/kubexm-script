#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: lb.exists
# 负载均衡存在检查（用于 lb_mode=exists，跳过安装）
# check: 检查 LB VIP:port 是否可达
# run:   无需操作（LB 已存在，不安装）
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

# 从配置获取 LB 地址和端口
_lb_exists_get_vip() {
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local lb_vip lb_port
  lb_vip=$(config::get_loadbalancer_vip 2>/dev/null || echo "")
  lb_port=$(config::get_loadbalancer_port 2>/dev/null || echo "6443")
  echo "${lb_vip:-} ${lb_port}"
}

step::lb.exists::check() {
  local ctx="${1:-}"
  shift
  local host="${1:-}"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  # 获取 LB VIP 和端口
  local lb_info vip port
  lb_info=$(_lb_exists_get_vip)
  vip=$(echo "${lb_info}" | cut -d' ' -f1)
  port=$(echo "${lb_info}" | cut -d' ' -f2)

  if [[ -z "${vip}" ]]; then
    logger::warn "[lb.exists] LB VIP not configured, cannot verify reachability"
    return 0  # 宽松：没有配置则跳过检查
  fi

  # TCP 检测 LB 端口是否可达（6443 = kube-apiserver 端口）
  if timeout 5 bash -c "echo >/dev/tcp/${vip}/${port}" 2>/dev/null; then
    logger::info "[lb.exists] LB ${vip}:${port} is reachable"
    return 0  # 已满足，跳过安装
  fi

  logger::error "[lb.exists] LB ${vip}:${port} is NOT reachable"
  return 1  # LB 不可达，但这是配置问题，不是安装错误
}

step::lb.exists::run() {
  # LB 已存在，不需要任何操作
  return 0
}

step::lb.exists::rollback() { return 0; }

step::lb.exists::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  # 只需要在本地检查 LB，不需要针对特定主机
  runner::normalize_host ""
}
