#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Kubeadm Task - Remove
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubelet::remove() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.delete.node.drain:${KUBEXM_ROOT}/internal/task/common/delete_node_drain.sh" \
    "cluster.delete.node:${KUBEXM_ROOT}/internal/task/common/delete_node.sh" \
    "cluster.reset.iptables:${KUBEXM_ROOT}/internal/task/common/reset_iptables.sh" \
    "cluster.reset.ipvs:${KUBEXM_ROOT}/internal/task/common/reset_ipvs.sh" \
    "cluster.stop.kubelet:${KUBEXM_ROOT}/internal/task/common/stop_kubelet.sh" \
    "cluster.disable.kubelet:${KUBEXM_ROOT}/internal/task/common/disable_kubelet.sh" \
    "cluster.cleanup.k8s.dirs:${KUBEXM_ROOT}/internal/task/common/cleanup_k8s_dirs.sh" \
    "cluster.cleanup.kubeconfig.file:${KUBEXM_ROOT}/internal/task/common/cleanup_kubeconfig_file.sh" \
    "cluster.cleanup.kubeconfig.cache:${KUBEXM_ROOT}/internal/task/common/cleanup_kubeconfig_cache.sh" \
    "cluster.cleanup.pki.etcd.dir:${KUBEXM_ROOT}/internal/task/common/cleanup_pki_etcd_dir.sh" \
    "cluster.cleanup.pki.dir:${KUBEXM_ROOT}/internal/task/common/cleanup_pki_dir.sh"
}

task::kubeadm::reset() {
  local ctx="$1"
  shift
  local k8s_type
  k8s_type=$(config::get_kubernetes_type 2>/dev/null || echo "kubeadm")
  if [[ "${k8s_type}" == "kubeadm" ]]; then
    task::run_steps "${ctx}" "$@" -- \
      "cluster.reset.kubeadm.cmd:${KUBEXM_ROOT}/internal/task/kubeadm/cluster/reset_kubeadm_cmd.sh"
  else
    # kubexm type: stop all kubernetes component services and cleanup
    logger::info "[Task:kubeadm::reset] Resetting kubexm cluster (stopping services and cleaning up)..."
    task::run_steps "${ctx}" "$@" -- \
      "cluster.stop.kubelet:${KUBEXM_ROOT}/internal/task/common/stop_kubelet.sh" \
      "cluster.disable.kubelet:${KUBEXM_ROOT}/internal/task/common/disable_kubelet.sh" \
      "cluster.cleanup.k8s.dirs:${KUBEXM_ROOT}/internal/task/common/cleanup_k8s_dirs.sh" \
      "cluster.cleanup.kubeconfig.file:${KUBEXM_ROOT}/internal/task/common/cleanup_kubeconfig_file.sh" \
      "cluster.cleanup.kubeconfig.cache:${KUBEXM_ROOT}/internal/task/common/cleanup_kubeconfig_cache.sh" \
      "cluster.cleanup.pki.etcd.dir:${KUBEXM_ROOT}/internal/task/common/cleanup_pki_etcd_dir.sh" \
      "cluster.cleanup.pki.dir:${KUBEXM_ROOT}/internal/task/common/cleanup_pki_dir.sh" \
      "cluster.reset.kubexm.services:${KUBEXM_ROOT}/internal/task/common/reset_kubexm_services.sh"
  fi
}

export -f task::kubelet::remove
export -f task::kubeadm::reset