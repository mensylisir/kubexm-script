#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# kubeadm Module
# ==============================================================================
# kubeadm 部署模块，包含：
# - 分发 kubeadm/kubectl/kubelet 二进制
# - kubeadm init master
# - kubeadm join master/worker
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/common/config.sh"
source "${KUBEXM_ROOT}/internal/task/common/ntp.sh"
source "${KUBEXM_ROOT}/internal/task/common/binaries.sh"
source "${KUBEXM_ROOT}/internal/task/kubeadm/main.sh"

# -----------------------------------------------------------------------------
# 分发 kubeadm/kubectl/kubelet 二进制
# -----------------------------------------------------------------------------
module::kubeadm_distribute_binaries() {
  local ctx="$1"
  shift
  task::distribute_kubeadm_binaries "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# kubeadm init master
# -----------------------------------------------------------------------------
module::kubeadm_init_master() {
  local ctx="$1"
  shift

  local etcd_type
  etcd_type=$(config::get_etcd_type)

  if [[ "${etcd_type}" == "kubeadm" ]]; then
    task::kubeadm_init_master "${ctx}" "$@" || return $?
  else
    task::kubeadm_init_external_etcd "${ctx}" "$@" || return $?
  fi
}

# -----------------------------------------------------------------------------
# 获取 kubeconfig
# -----------------------------------------------------------------------------
module::kubeadm_fetch_kubeconfig() {
  local ctx="$1"
  shift
  task::kubeadm_fetch_kubeconfig "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# 准备 join
# -----------------------------------------------------------------------------
module::kubeadm_prepare_join() {
  local ctx="$1"
  shift
  task::kubeadm_prepare_join "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# Join master 节点
# -----------------------------------------------------------------------------
module::kubeadm_join_master() {
  local ctx="$1"
  shift
  task::kubeadm_join_master "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# Join worker 节点
# -----------------------------------------------------------------------------
module::kubeadm_join_worker() {
  local ctx="$1"
  shift
  task::kubeadm_join_worker "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# 完整 kubeadm 部署流程
# -----------------------------------------------------------------------------
module::kubeadm_install() {
  local ctx="$1"
  shift

  # 分发二进制
  module::kubeadm_distribute_binaries "${ctx}" "$@" || return $?

  # 初始化 master
  module::kubeadm_init_master "${ctx}" "$@" || return $?

  # 获取 kubeconfig
  module::kubeadm_fetch_kubeconfig "${ctx}" "$@" || return $?

  # 准备 join
  module::kubeadm_prepare_join "${ctx}" "$@" || return $?

  # Join master
  module::kubeadm_join_master "${ctx}" "$@" || return $?

  # Join worker
  module::kubeadm_join_worker "${ctx}" "$@" || return $?
}

export -f module::kubeadm_distribute_binaries
export -f module::kubeadm_init_master
export -f module::kubeadm_fetch_kubeconfig
export -f module::kubeadm_prepare_join
export -f module::kubeadm_join_master
export -f module::kubeadm_join_worker
export -f module::kubeadm_install