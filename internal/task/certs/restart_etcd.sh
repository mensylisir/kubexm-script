#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Certificate Renew - Restart ETCD Task
# ==============================================================================
# ETCD 证书续期后重启 etcd 服务使新证书生效
# ==============================================================================

task::restart_etcd_after_cert_renew() {
  local ctx="$1"
  shift
  _="${ctx}" # context passed for consistency with other task signatures
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  log::info "=== Restarting etcd after certificate renewal ==="

  local etcd_nodes
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane')

  for node in ${etcd_nodes}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -z "${node_ip}" ]] && continue

    log::info "Restarting etcd on ${node_ip}..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${node_ip}" \
      "systemctl daemon-reload && systemctl restart etcd" || {
      log::warn "Failed to restart etcd on ${node_ip}"
      continue
    }

    # 等待 etcd 启动
    sleep 3

    # 健康检查
    local health
    health=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${node_ip}" \
      "ETCDCTL_API=3 etcdctl endpoint health --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key 2>/dev/null" || echo "failed")
    if [[ "${health}" == *"healthy"* ]]; then
      log::info "etcd on ${node_ip} is healthy after restart"
    else
      log::warn "etcd on ${node_ip} may not be healthy: ${health}"
    fi
  done

  log::info "=== etcd restarted successfully ==="
}

export -f task::restart_etcd_after_cert_renew
