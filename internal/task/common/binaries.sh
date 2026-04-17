#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Cluster Task - Kubernetes Binaries Distribution
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::distribute_kubeadm_binaries() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.distribute.binaries.kubeadm.collect.cluster.name:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/distribute_binaries_collect_cluster_name.sh" \
    "kubernetes.distribute.binaries.kubeadm.collect.node.name:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/distribute_binaries_collect_node_name.sh" \
    "kubernetes.distribute.binaries.kubeadm.collect.arch:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/distribute_binaries_collect_arch.sh" \
    "kubernetes.distribute.binaries.kubeadm.collect.paths:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/distribute_binaries_collect_paths.sh" \
    "kubernetes.distribute.binaries.kubeadm:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/distribute_binaries.sh"
}

task::distribute_kubexm_binaries() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.distribute.binaries.kubexm.collect.cluster.name:${KUBEXM_ROOT}/internal/step/kubexm/binaries/collect_cluster_name.sh" \
    "kubernetes.distribute.binaries.kubexm.collect.node.name:${KUBEXM_ROOT}/internal/step/kubexm/binaries/collect_node_name.sh" \
    "kubernetes.distribute.binaries.kubexm.collect.arch:${KUBEXM_ROOT}/internal/step/kubexm/binaries/collect_arch.sh" \
    "kubernetes.distribute.binaries.kubexm.collect.paths:${KUBEXM_ROOT}/internal/step/kubexm/binaries/collect_paths.sh" \
    "kubernetes.distribute.binaries.kubexm:${KUBEXM_ROOT}/internal/step/kubexm/binaries/distribute_binaries.sh"
}

task::distribute_k8s_binaries() {
  local ctx="$1"
  shift
  local k8s_type
  k8s_type=$(config::get_kubernetes_type)
  if [[ "${k8s_type}" == "kubeadm" ]]; then
    task::distribute_kubeadm_binaries "${ctx}" "$@"
  else
    task::distribute_kubexm_binaries "${ctx}" "$@"
  fi
}

export -f task::distribute_kubeadm_binaries
export -f task::distribute_kubexm_binaries
export -f task::distribute_k8s_binaries