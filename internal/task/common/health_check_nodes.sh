#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: health_check_nodes
# 检查所有节点状态
# ==============================================================================


step::health.check.nodes() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host:-localhost} step=health.check_nodes] Checking node status..."

  # 获取所有节点状态
  local nodes
  nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "${nodes}" ]]; then
    logger::warn "[host=${host:-localhost}] No nodes found or cluster not reachable"
    return 1
  fi

  local node_array
  read -ra node_array <<< "${nodes}"

  local failed_nodes=()
  for node in "${node_array[@]}"; do
    local status
    status=$(kubectl get node "${node}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

    if [[ "${status}" != "True" ]]; then
      failed_nodes+=("${node}:${status}")
      logger::error "[node=${node}] Node is not ready"
    else
      logger::info "[node=${node}] Node is ready"
    fi
  done

  if [[ ${#failed_nodes[@]} -gt 0 ]]; then
    logger::error "[step=health.check_nodes] ${#failed_nodes[@]} node(s) not ready"
    return 1
  fi

  logger::info "[step=health.check_nodes] All ${#node_array[@]} nodes are ready"
  return 0
}

step::health.check.nodes::run() {
  step::health.check.nodes "$@"
}

step::health.check.nodes::check() {
  # 健康检查 step 始终执行
  return 1
}

step::health.check.nodes::rollback() { return 0; }

step::health.check.nodes::targets() {
  # kubectl 操作仅需在本地执行（使用 kubeconfig），不针对特定主机
  return 0
}
