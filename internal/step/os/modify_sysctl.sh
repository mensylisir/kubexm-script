#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os_modify_sysctl
# 设置内核参数（ip_forward, bridge-nf-call-iptables）
# ==============================================================================


step::os.modify.sysctl::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::os.modify.sysctl "$@"
}

step::os.modify.sysctl() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=os.modify_sysctl] Setting kernel parameters..."

  # 开启 IP 转发
  echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-kubexm.conf

  # 开启 bridge-nf-call-iptables
  echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/99-kubexm.conf
  echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/99-kubexm.conf

  # 应用配置
  sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-kubexm.conf

  logger::info "[host=${host} step=os.modify_sysctl] Kernel parameters configured"
  return 0
}

step::os.modify.sysctl::check() {
  # 检查参数是否已设置
  local ip_forward
  ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
  local bridge_nf
  bridge_nf=$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null || echo "0")

  if [[ "${ip_forward}" != "1" ]] || [[ "${bridge_nf}" != "1" ]]; then
    return 1  # 需要执行
  fi
  return 0  # 已配置，跳过
}

step::os.modify.sysctl::rollback() { return 0; }

step::os.modify.sysctl::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
