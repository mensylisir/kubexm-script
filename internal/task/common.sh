#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# KubeXM Script - Reusable Task Library
# ==============================================================================
# 可复用的 Task 组合，由多个 Step 组成
# 设计原则：一个 Task 完成一个完整的小功能，可被不同 Module 复用
# ==============================================================================

source "${KUBEXM_ROOT}/internal/step/lib/registry.sh"
source "${KUBEXM_ROOT}/internal/step/lib/step_runner.sh"

# Alias for backward compatibility - task layer uses step::run_steps internally
task::run_steps() {
  step::run_steps "$@"
}
export -f task::run_steps

# ==============================================================================
# 公共配置任务
# ==============================================================================

# 配置集群（解析参数、加载配置）
task::configure() {
  local ctx="$1"
  shift
  local cluster_name=""
  for arg in "$@"; do
    case "$arg" in
      --cluster=*) cluster_name="${arg#*=}" ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  parser::load_config
  parser::load_hosts
  config::validate_consistency || return 1
}

# ==============================================================================
# 工具检查任务
# ==============================================================================

task::check_tools() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "check.tools.binary:${KUBEXM_ROOT}/internal/step/common/checks/check_tools_binary.sh" \
    "check.tools.packages:${KUBEXM_ROOT}/internal/step/common/checks/check_tools_packages.sh"
}

# ==============================================================================
# 扩缩容 - 收集动作（确定是 scale-out 还是 scale-in）
# ==============================================================================

# Workers 收集动作
task::collect_workers_action() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.join.workers.collect.action:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_join_workers_collect_action.sh"
}

# Control-plane 收集动作
task::collect_cp_action() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.join.collect.action:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_join_collect_action.sh"
}

# ==============================================================================
# 扩缩容 - 收集节点信息
# ==============================================================================

task::collect_workers_info() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.join.workers.collect.node:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_join_workers_collect_node.sh"
}

task::collect_cp_info() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.join.collect.node:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_join_collect_node.sh"
}

# ==============================================================================
# 扩缩容 - 收集 Join 命令
# ==============================================================================

task::collect_workers_join_cmd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.join.workers.collect.command:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_join_workers_collect_command.sh"
}

task::collect_cp_join_cmd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.join.collect.command:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_join_collect_command.sh"
}

# ==============================================================================
# 扩缩容 - 执行 Join
# ==============================================================================

task::join_workers() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.join.workers.exec:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_join_workers_exec.sh"
}

task::join_cp() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.join.exec:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_join_exec.sh"
}

# ==============================================================================
# 扩缩容 - 等待节点就绪
# ==============================================================================

task::wait_nodes_ready() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.wait.ready:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_wait_ready.sh"
}

# ==============================================================================
# 缩容 - 驱逐节点
# ==============================================================================

task::drain_workers() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.drain.nodes:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_drain_nodes.sh"
}

task::drain_cp() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.drain.nodes:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_drain_nodes.sh"
}

# ==============================================================================
# 缩容 - 移除节点
# ==============================================================================

task::remove_workers() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.remove.nodes:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_remove_nodes.sh"
}

task::remove_cp() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.remove.nodes:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_remove_nodes.sh"
}

# ==============================================================================
# 缩容 - 停止 kubelet
# ==============================================================================

task::stop_kubelet_workers() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.stop.kubelet:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_stop_kubelet.sh"
}

task::stop_kubelet_cp() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.stop.kubelet:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_stop_kubelet.sh"
}

# ==============================================================================
# 缩容 - kubeadm reset
# ==============================================================================

task::kubeadm_reset_workers() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.kubeadm.reset:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_kubeadm_reset.sh"
}

task::kubeadm_reset_cp() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.kubeadm.reset:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_kubeadm_reset.sh"
}

# ==============================================================================
# 缩容 - 清理目录
# ==============================================================================

task::cleanup_dirs_workers() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cleanup.dirs:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cleanup_dirs.sh"
}

task::cleanup_dirs_cp() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.cp.cleanup.dirs:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_cleanup_dirs.sh"
}

# ==============================================================================
# 缩容 - 清理 iptables
# ==============================================================================

task::flush_iptables() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.flush.iptables:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_flush_iptables.sh"
}

# ==============================================================================
# Preflight - 主机连通性检查
# ==============================================================================

# 执行主机连通性检查 step（通过 task::run_steps）
# 用法: task::preflight_check_host <ctx>
task::preflight_check_host() {
  local ctx="${1:-}"
  task::run_steps "${ctx}" -- \
    "preflight.check.host:${KUBEXM_ROOT}/internal/step/preflight/preflight_check_host.sh"
}

# ==============================================================================
# 缩容 - 更新负载均衡
# ==============================================================================

task::update_lb_config() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.scale.update.lb.collect.workers:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_update_lb_collect_workers.sh" \
    "cluster.scale.update.lb.render.haproxy:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_update_lb_render_haproxy.sh" \
    "cluster.scale.update.lb.render.nginx:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_update_lb_render_nginx.sh" \
    "cluster.scale.update.lb.kube.vip.notice:${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_update_lb_kube_vip_notice.sh"
}

# ==============================================================================
# 导出函数
# ==============================================================================

export -f task::configure
export -f task::check_tools
export -f task::preflight_check_host
export -f task::collect_workers_action
export -f task::collect_cp_action
export -f task::collect_workers_info
export -f task::collect_cp_info
export -f task::collect_workers_join_cmd
export -f task::collect_cp_join_cmd
export -f task::join_workers
export -f task::join_cp
export -f task::wait_nodes_ready
export -f task::drain_workers
export -f task::drain_cp
export -f task::remove_workers
export -f task::remove_cp
export -f task::stop_kubelet_workers
export -f task::stop_kubelet_cp
export -f task::kubeadm_reset_workers
export -f task::kubeadm_reset_cp
export -f task::cleanup_dirs_workers
export -f task::cleanup_dirs_cp
export -f task::flush_iptables
export -f task::update_lb_config