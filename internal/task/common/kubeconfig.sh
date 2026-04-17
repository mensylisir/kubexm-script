#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - Kubeconfig (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubexm_generate_kubeconfig() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.generate.kubeconfig.node.collect.endpoint:${KUBEXM_ROOT}/internal/step/kubexm/kubeconfig/generate_kubeconfig_node_collect_endpoint.sh" \
    "kubernetes.generate.kubeconfig.node.collect.paths:${KUBEXM_ROOT}/internal/step/kubexm/kubeconfig/generate_kubeconfig_node_collect_paths.sh" \
    "kubernetes.generate.kubeconfig.node.generate:${KUBEXM_ROOT}/internal/step/kubexm/kubeconfig/generate_kubeconfig_node_generate.sh" \
    "kubernetes.generate.kubeconfig.global:${KUBEXM_ROOT}/internal/step/kubexm/kubeconfig/generate_kubeconfig_global.sh"
}

task::kubexm_distribute_kubeconfig() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.distribute.kubeconfig.files:${KUBEXM_ROOT}/internal/step/kubexm/kubeconfig/distribute_kubeconfig_files.sh" \
    "kubernetes.distribute.kubeconfig.admin:${KUBEXM_ROOT}/internal/step/kubexm/kubeconfig/distribute_kubeconfig_admin.sh" \
    "kubernetes.fix.kubeconfig.permissions:${KUBEXM_ROOT}/internal/step/kubexm/kubeconfig/fix_kubeconfig_permissions.sh"
}

export -f task::kubexm_generate_kubeconfig
export -f task::kubexm_distribute_kubeconfig