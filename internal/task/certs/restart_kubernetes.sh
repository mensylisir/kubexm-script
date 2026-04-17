#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Certificate Renew - Restart Kubernetes Components Task
# ==============================================================================
# 证书续期后重启相关服务使新证书生效
# ==============================================================================

task::restart_kubernetes_after_cert_renew() {
  local ctx="$1"
  shift
  _="${ctx}" # context passed for consistency with other task signatures
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  log::info "=== Restarting Kubernetes components after certificate renewal ==="

  local k8s_type
  k8s_type=$(config::get_kubernetes_type 2>/dev/null || echo kubeadm)

  if [[ "${k8s_type}" == "kubexm" ]]; then
    # kubexm 类型：重启独立组件
    local cp_nodes
    cp_nodes=$(config::get_role_members 'control-plane')
    for node in ${cp_nodes}; do
      local node_ip
      node_ip=$(config::get_host_param "${node}" "address")
      [[ -z "${node_ip}" ]] && continue
      log::info "Restarting kube-apiserver on ${node_ip}..."
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${node_ip}" \
        "systemctl restart kube-apiserver || true" || log::warn "Failed to restart kube-apiserver on ${node_ip}"
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${node_ip}" \
        "systemctl restart kube-controller-manager || true" || log::warn "Failed to restart kube-controller-manager on ${node_ip}"
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${node_ip}" \
        "systemctl restart kube-scheduler || true" || log::warn "Failed to restart kube-scheduler on ${node_ip}"
    done
  else
    # kubeadm 类型：重启 kubelet（会自动重启 static pod）
    local all_nodes
    all_nodes=$(config::get_role_members 'control-plane')
    all_nodes="${all_nodes} $(config::get_role_members 'worker')"
    for node in ${all_nodes}; do
      local node_ip
      node_ip=$(config::get_host_param "${node}" "address")
      [[ -z "${node_ip}" ]] && continue
      log::info "Restarting kubelet on ${node_ip}..."
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${node_ip}" \
        "systemctl daemon-reload && systemctl restart kubelet" || log::warn "Failed to restart kubelet on ${node_ip}"
    done
  fi

  log::info "=== Kubernetes components restarted successfully ==="
}

export -f task::restart_kubernetes_after_cert_renew
