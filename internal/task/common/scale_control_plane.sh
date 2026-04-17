#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Scale Cluster Task - Control Plane
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# Scale-out Control-plane 流程 (与 workers 类似，但节点角色不同)
# -----------------------------------------------------------------------------
task::scale_out_cp() {
  local ctx="$1"
  shift
  task::collect_cp_action      "${ctx}" "$@"
  task::collect_cp_info        "${ctx}" "$@"
  task::collect_cp_join_cmd    "${ctx}" "$@"
  task::join_cp                "${ctx}" "$@"
  task::wait_nodes_ready       "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# Scale-in Control-plane 流程 (与 workers 类似)
# -----------------------------------------------------------------------------
task::scale_in_cp() {
  local ctx="$1"
  shift
  task::collect_cp_action      "${ctx}" "$@"
  task::drain_cp               "${ctx}" "$@"
  task::stop_kubelet_cp        "${ctx}" "$@"
  task::kubeadm_reset_cp       "${ctx}" "$@"
  task::cleanup_dirs_cp        "${ctx}" "$@"
  task::flush_iptables         "${ctx}" "$@"
  task::update_lb_config       "${ctx}" "$@"
}

export -f task::scale_out_cp
export -f task::scale_in_cp
