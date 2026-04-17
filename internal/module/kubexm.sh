#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# kubexm Module
# ==============================================================================
# kubexm 二进制部署模块，包含：
# - 分发 kubexm 二进制
# - kubeconfig 生成和分发
# - PKI 分发
# - API Server / Controller Manager / Scheduler 部署
# - Kubelet / Kube Proxy 部署
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/common/config.sh"
source "${KUBEXM_ROOT}/internal/task/common/ntp.sh"
source "${KUBEXM_ROOT}/internal/task/common/binaries.sh"
source "${KUBEXM_ROOT}/internal/task/kubeadm/main.sh"
source "${KUBEXM_ROOT}/internal/task/common/kubeconfig.sh"
source "${KUBEXM_ROOT}/internal/task/common/pki.sh"
source "${KUBEXM_ROOT}/internal/task/common/production_configs.sh"
source "${KUBEXM_ROOT}/internal/task/common/apiserver.sh"
source "${KUBEXM_ROOT}/internal/task/common/controller_manager.sh"
source "${KUBEXM_ROOT}/internal/task/common/scheduler.sh"
source "${KUBEXM_ROOT}/internal/task/common/kubelet.sh"
source "${KUBEXM_ROOT}/internal/task/common/kube_proxy.sh"
source "${KUBEXM_ROOT}/internal/task/common/control_plane.sh"
source "${KUBEXM_ROOT}/internal/task/common/workers.sh"

# -----------------------------------------------------------------------------
# 分发 kubexm 二进制
# -----------------------------------------------------------------------------
module::kubexm_distribute_binaries() {
  local ctx="$1"
  shift
  task::distribute_kubexm_binaries "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# kubeconfig 管理
# -----------------------------------------------------------------------------
module::kubexm_generate_kubeconfig() {
  local ctx="$1"
  shift
  task::kubexm_generate_kubeconfig "${ctx}" "$@" || return $?
}

module::kubexm_distribute_kubeconfig() {
  local ctx="$1"
  shift
  task::kubexm_distribute_kubeconfig "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# PKI 分发
# -----------------------------------------------------------------------------
module::kubexm_distribute_pki() {
  local ctx="$1"
  shift
  task::kubexm_distribute_pki "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# Control Plane 组件
# -----------------------------------------------------------------------------
module::kubexm_install_apiserver() {
  local ctx="$1"
  shift
  task::kubexm_install_apiserver "${ctx}" "$@" || return $?
}

module::kubexm_install_controller_manager() {
  local ctx="$1"
  shift
  task::kubexm_install_controller_manager "${ctx}" "$@" || return $?
}

module::kubexm_install_scheduler() {
  local ctx="$1"
  shift
  task::kubexm_install_scheduler "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# 等待 Control Plane 就绪
# -----------------------------------------------------------------------------
module::kubexm_wait_control_plane() {
  local ctx="$1"
  shift
  task::kubexm_wait_control_plane "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# Worker 组件
# -----------------------------------------------------------------------------
module::kubexm_install_kubelet() {
  local ctx="$1"
  shift
  task::kubexm_install_kubelet "${ctx}" "$@" || return $?
}

module::kubexm_install_kube_proxy() {
  local ctx="$1"
  shift
  task::kubexm_install_kube_proxy "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# 完整 kubexm 部署 Control Plane
# -----------------------------------------------------------------------------
module::kubexm_install_control_plane() {
  local ctx="$1"
  shift

  # 生成生产配置 (audit policy, encryption config)
  task::generate_production_configs "${ctx}" "$@" || return $?

  # kubeconfig
  module::kubexm_generate_kubeconfig "${ctx}" "$@" || return $?
  module::kubexm_distribute_kubeconfig "${ctx}" "$@" || return $?

  # PKI
  module::kubexm_distribute_pki "${ctx}" "$@" || return $?

  # Control Plane 组件
  module::kubexm_install_apiserver "${ctx}" "$@" || return $?
  module::kubexm_install_controller_manager "${ctx}" "$@" || return $?
  module::kubexm_install_scheduler "${ctx}" "$@" || return $?

  # 等待就绪
  module::kubexm_wait_control_plane "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# 完整 kubexm 部署 Workers
# -----------------------------------------------------------------------------
module::kubexm_install_workers() {
  local ctx="$1"
  shift

  module::kubexm_install_kubelet "${ctx}" "$@" || return $?
  module::kubexm_install_kube_proxy "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# 完整 kubexm 部署
# -----------------------------------------------------------------------------
module::kubexm_install() {
  local ctx="$1"
  shift

  # 分发二进制
  module::kubexm_distribute_binaries "${ctx}" "$@" || return $?

  # 部署 Control Plane
  module::kubexm_install_control_plane "${ctx}" "$@" || return $?

  # 部署 Workers
  module::kubexm_install_workers "${ctx}" "$@" || return $?
}

export -f module::kubexm_distribute_binaries
export -f module::kubexm_generate_kubeconfig
export -f module::kubexm_distribute_kubeconfig
export -f module::kubexm_distribute_pki
export -f module::kubexm_install_apiserver
export -f module::kubexm_install_controller_manager
export -f module::kubexm_install_scheduler
export -f module::kubexm_wait_control_plane
export -f module::kubexm_install_kubelet
export -f module::kubexm_install_kube_proxy
export -f module::kubexm_install_control_plane
export -f module::kubexm_install_workers
export -f module::kubexm_install