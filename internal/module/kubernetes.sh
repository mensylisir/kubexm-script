#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Module
# ==============================================================================
# Kubernetes 部署模块，根据配置选择 kubeadm 或 kubexm
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/module/kubeadm.sh"
source "${KUBEXM_ROOT}/internal/module/kubexm.sh"

# -----------------------------------------------------------------------------
# 自动选择部署方式
# -----------------------------------------------------------------------------
module::kubernetes_install() {
  local ctx="$1"
  shift

  local k8s_type
  k8s_type=$(config::get_kubernetes_type)

  if [[ "${k8s_type}" == "kubeadm" ]]; then
    module::kubeadm_install "${ctx}" "$@" || return $?
  else
    module::kubexm_install "${ctx}" "$@" || return $?
  fi
}

export -f module::kubernetes_install