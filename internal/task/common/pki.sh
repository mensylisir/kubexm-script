#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - PKI Distribution (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubexm_distribute_pki() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.distribute.pki.k8s.collect.cluster.name:${KUBEXM_ROOT}/internal/step/kubernetes/pki/kubeadm/distribute_pki_k8s_collect_cluster_name.sh" \
    "kubernetes.distribute.pki.k8s.collect.node.name:${KUBEXM_ROOT}/internal/step/kubernetes/pki/kubeadm/distribute_pki_k8s_collect_node_name.sh" \
    "kubernetes.distribute.pki.k8s.collect.pki.dir:${KUBEXM_ROOT}/internal/step/kubernetes/pki/kubeadm/distribute_pki_k8s_collect_pki_dir.sh" \
    "kubernetes.distribute.pki.k8s.collect.role.flag:${KUBEXM_ROOT}/internal/step/kubernetes/pki/kubeadm/distribute_pki_k8s_collect_role_flag.sh" \
    "kubernetes.distribute.pki.k8s.copy:${KUBEXM_ROOT}/internal/step/kubernetes/pki/kubeadm/distribute_pki_k8s_copy.sh" \
    "kubernetes.distribute.pki.k8s.permissions:${KUBEXM_ROOT}/internal/step/kubernetes/pki/kubeadm/distribute_pki_k8s_permissions.sh" \
    "kubernetes.distribute.pki.etcd.ca:${KUBEXM_ROOT}/internal/step/kubernetes/pki/kubeadm/distribute_pki_etcd_ca.sh"
}

export -f task::kubexm_distribute_pki