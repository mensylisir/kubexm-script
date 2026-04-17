#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os_stop_firewall
# 关闭防火墙并清理 iptables
# ==============================================================================


step::os.stop.firewall::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::os.stop.firewall "$@"
}

step::os.stop.firewall() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=os.stop_firewall] Stopping firewall..."

  # 检测并停止 firewalld
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    systemctl stop firewalld || true
    systemctl disable firewalld || true
  fi

  # 检测并停止 ufw
  if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    ufw disable || true
  fi

  # 清理 iptables
  iptables -F || true
  iptables -X || true
  iptables -Z || true

  logger::info "[host=${host} step=os.stop_firewall] Firewall stopped"
  return 0
}

step::os.stop.firewall::check() {
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    return 1  # 需要执行
  fi
  return 0  # 已停止，跳过
}

step::os.stop.firewall::rollback() { return 0; }

step::os.stop.firewall::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
