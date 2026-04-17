#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Scale Cluster Task - Workers
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# Scale-out Workers 流程
#   1. 收集动作 (确定是 scale-out)
#   2. 收集节点信息
#   3. 收集 join 命令
#   4. 执行 join
#   5. 等待就绪
# -----------------------------------------------------------------------------
task::scale_out_workers() {
  local ctx="$1"
  shift
  task::collect_workers_action  "${ctx}" "$@"
  task::collect_workers_info    "${ctx}" "$@"
  task::collect_workers_join_cmd "${ctx}" "$@"
  task::join_workers             "${ctx}" "$@"
  task::wait_nodes_ready         "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# Scale-in Workers 流程
#   1. 收集动作 (确定是 scale-in)
#   2. 驱逐节点
#   3. 停止 kubelet
#   4. kubeadm reset
#   5. 清理目录
#   6. 清理 iptables
#   7. 更新负载均衡
# -----------------------------------------------------------------------------
task::scale_in_workers() {
  local ctx="$1"
  shift
  task::collect_workers_action  "${ctx}" "$@"
  task::drain_workers           "${ctx}" "$@"
  task::stop_kubelet_workers    "${ctx}" "$@"
  task::kubeadm_reset_workers   "${ctx}" "$@"
  task::cleanup_dirs_workers    "${ctx}" "$@"
  task::flush_iptables          "${ctx}" "$@"
  task::update_lb_config        "${ctx}" "$@"
}

export -f task::scale_out_workers
export -f task::scale_in_workers
