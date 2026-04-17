#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: configure_hosts
# 配置 /etc/hosts，添加节点 hostname 和 registry 域名映射
# ==============================================================================

step::os.configure.hosts::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  # 检查是否已经配置过（通过标记文件判断）
  local hosts_marker="/etc/kubexm-hosts.marker"
  if runner::remote_exec "test -f ${hosts_marker}" 2>/dev/null; then
    return 0  # 已配置，跳过
  fi
  return 1  # 需要配置
}

step::os.configure.hosts::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  # 生成 hosts 内容
  local hosts_content="# kubexm managed hosts - start
# Cluster nodes"
  local all_nodes
  all_nodes=$(config::get_all_host_names)
  for node in ${all_nodes}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ -n "${node_ip}" ]]; then
      hosts_content+="
${node_ip} ${node}"
    fi
  done

  # Registry 域名（如果启用）
  local registry_enabled
  registry_enabled=$(config::get_registry_enabled 2>/dev/null || echo "false")
  if [[ "${registry_enabled}" == "true" ]]; then
    local registry_host
    registry_host=$(config::get_registry_host 2>/dev/null || echo "")
    local registry_port
    registry_port=$(config::get_registry_port 2>/dev/null || echo "5000")
    if [[ -n "${registry_host}" ]]; then
      hosts_content+="
# Registry
${registry_host} ${registry_host}:${registry_port}"
    fi
  fi

  hosts_content+="
# kubexm managed hosts - end"

  # 备份原有 hosts
  runner::remote_exec "cp /etc/hosts /etc/hosts.kubexm.bak 2>/dev/null || true"

  # 移除旧的 kubexm 管理部分
  runner::remote_exec "sed -i '/# kubexm managed hosts - start/,/# kubexm managed hosts - end/d' /etc/hosts 2>/dev/null || true"

  # 添加新的 hosts 内容
  runner::remote_exec "echo '${hosts_content}' >> /etc/hosts"

  # 创建标记文件
  runner::remote_exec "touch /etc/kubexm-hosts.marker"

  logger::info "[hosts] /etc/hosts configured"
}

step::os.configure.hosts::rollback() { return 0; }

step::os.configure.hosts::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_hosts
}
