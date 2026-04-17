#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Scale Cluster Task - Main
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/common/scale_workers.sh"
source "${KUBEXM_ROOT}/internal/task/common/scale_control_plane.sh"
source "${KUBEXM_ROOT}/internal/task/common/scale_hosts.sh"

# -----------------------------------------------------------------------------
# 完整扩缩容流程
#   根据 action 参数自动选择 scale-out 或 scale-in
# -----------------------------------------------------------------------------
task::scale_cluster() {
  local ctx="$1"
  shift
  local args=("$@")

  # 1. 配置集群
  task::configure "${ctx}" "${args[@]}" || return $?

  # 2. 检查工具
  KUBEXM_TOOL_CHECKS="jq yq xmjq xmyq"
  task::check_tools "${ctx}" "${args[@]}" || return $?

  # 3. 执行 Workers 扩缩容
  #    collect_action 会设置 context::scale_join_skip 来决定是否跳过
  task::collect_workers_action "${ctx}" "${args[@]}"
  local skip
  skip="$(context::get "cluster_scale_join_skip" || true)"
  if [[ "${skip}" != "true" ]]; then
    # scale-out 流程
    task::collect_workers_info     "${ctx}" "${args[@]}"
    task::collect_workers_join_cmd "${ctx}" "${args[@]}"
    task::join_workers             "${ctx}" "${args[@]}"
    task::wait_nodes_ready         "${ctx}" "${args[@]}"
  else
    # scale-in 流程
    task::drain_workers            "${ctx}" "${args[@]}"
    task::stop_kubelet_workers     "${ctx}" "${args[@]}"
    task::kubeadm_reset_workers   "${ctx}" "${args[@]}"
    task::cleanup_dirs_workers     "${ctx}" "${args[@]}"
    task::flush_iptables           "${ctx}" "${args[@]}"
    task::update_lb_config         "${ctx}" "${args[@]}"
  fi

  # 4. 执行 Control-plane 扩缩容 (类似流程)
  task::collect_cp_action "${ctx}" "${args[@]}"
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" != "true" ]]; then
    # scale-out 流程
    task::collect_cp_info          "${ctx}" "${args[@]}"
    task::collect_cp_join_cmd     "${ctx}" "${args[@]}"
    task::join_cp                 "${ctx}" "${args[@]}"
    task::wait_nodes_ready        "${ctx}" "${args[@]}"
  else
    # scale-in 流程
    task::drain_cp                "${ctx}" "${args[@]}"
    task::stop_kubelet_cp         "${ctx}" "${args[@]}"
    task::kubeadm_reset_cp        "${ctx}" "${args[@]}"
    task::cleanup_dirs_cp          "${ctx}" "${args[@]}"
    task::flush_iptables          "${ctx}" "${args[@]}"
    task::update_lb_config        "${ctx}" "${args[@]}"
  fi
}

export -f task::scale_cluster
