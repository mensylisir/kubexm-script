#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os.update_hosts
# 更新 /etc/hosts，添加所有集群节点 IP + hostname + registry 域名
# 安装集群时在每台机器上写入，删除集群时清理
# ==============================================================================

step::os.update.hosts::check() {
  return 1  # Always run to ensure /etc/hosts is current
}

step::os.update.hosts::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  # Generate hosts content with ALL cluster nodes
  local hosts_content="# kubexm managed hosts - ${KUBEXM_CLUSTER_NAME:-default} - start"

  # Add all nodes from host.yaml
  local all_nodes
  all_nodes=$(config::get_all_host_names 2>/dev/null || true)
  for node in ${all_nodes}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ -n "${node_ip}" ]]; then
      hosts_content+="
${node_ip} ${node}"
    fi
  done

  # Add control-plane VIP if using keepalived
  local lb_enabled
  lb_enabled=$(config::get_loadbalancer_enabled 2>/dev/null || echo "false")
  if [[ "${lb_enabled}" == "true" ]]; then
    local lb_mode
    lb_mode=$(config::get_loadbalancer_mode 2>/dev/null || echo "")
    if [[ "${lb_mode}" == "external" || "${lb_mode}" == "kube-vip" ]]; then
      local vip
      vip=$(config::get_loadbalancer_vip 2>/dev/null || echo "")
      local vip_hostname
      vip_hostname=$(config::get_kubernetes_api_endpoint_domain 2>/dev/null || echo "")
      if [[ -n "${vip}" && -n "${vip_hostname}" ]]; then
        hosts_content+="
${vip} ${vip_hostname}"
      fi
    fi
  fi

  # Registry hostname mapping
  local registry_enabled
  registry_enabled=$(config::get_registry_enabled 2>/dev/null || echo "false")
  if [[ "${registry_enabled}" == "true" ]]; then
    local registry_host_name
    registry_host_name=$(config::get_registry_host 2>/dev/null || echo "")
    local registry_ip
    registry_ip=$(config::get_registry_host_ip 2>/dev/null || echo "")
    if [[ -n "${registry_host_name}" && -n "${registry_ip}" ]]; then
      hosts_content+="
${registry_ip} ${registry_host_name}"
    fi
  fi

  hosts_content+="
# kubexm managed hosts - ${KUBEXM_CLUSTER_NAME:-default} - end"

  # Test SSH connectivity (skip if unreachable, e.g. during scale-in)
  if ! timeout 5 runner::remote_exec "echo ok" >/dev/null 2>&1; then
    log::warn "[hosts] Node ${KUBEXM_HOST:-unknown} unreachable, skipping"
    return 0
  fi

  # Remove old kubexm section for this cluster and append new
  runner::remote_exec "sed -i '/# kubexm managed hosts - ${KUBEXM_CLUSTER_NAME:-default} - start/,/# kubexm managed hosts - ${KUBEXM_CLUSTER_NAME:-default} - end/d' /etc/hosts 2>/dev/null || true"
  runner::remote_exec "echo '${hosts_content}' >> /etc/hosts"
  runner::remote_exec "touch /etc/kubexm-hosts-${KUBEXM_CLUSTER_NAME:-default}.marker"

  log::info "[hosts] /etc/hosts updated on ${KUBEXM_HOST}"
}

step::os.update.hosts::rollback() { return 0; }

step::os.update.hosts::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_hosts
}
