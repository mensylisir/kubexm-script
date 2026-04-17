#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Certificates Module
# ==============================================================================
# 证书模块，包含：
# - 收集证书配置目录
# - 初始化节点证书
# - 收集 Control Plane / Worker / Etcd 证书
# - 证书自动续期
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/certs/init.sh"
source "${KUBEXM_ROOT}/internal/task/certs/collect.sh"
source "${KUBEXM_ROOT}/internal/task/certs/auto_renew.sh"
source "${KUBEXM_ROOT}/internal/task/certs/renew.sh"

# -----------------------------------------------------------------------------
# 工具检查
# -----------------------------------------------------------------------------
module::check_tools() {
  local ctx="$1"
  shift
  task::check_tools "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 收集证书配置目录
# -----------------------------------------------------------------------------
module::certs_collect_config() {
  local ctx="$1"
  shift
  task::collect_certs_config_dirs "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 初始化节点证书
# -----------------------------------------------------------------------------
module::certs_init_node() {
  local ctx="$1"
  shift
  task::init_node_certs "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 收集 Control Plane 证书
# -----------------------------------------------------------------------------
module::certs_collect_cp() {
  local ctx="$1"
  shift
  task::collect_cp_certs "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 收集 Worker 证书
# -----------------------------------------------------------------------------
module::certs_collect_worker() {
  local ctx="$1"
  shift
  task::collect_worker_certs "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 收集 Etcd 证书
# -----------------------------------------------------------------------------
module::certs_collect_etcd() {
  local ctx="$1"
  shift
  task::collect_etcd_certs "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 设置证书自动续期
# -----------------------------------------------------------------------------
module::certs_setup_auto_renew() {
  local ctx="$1"
  shift
  task::setup_cert_auto_renew "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 续期 Kubernetes CA
# -----------------------------------------------------------------------------
module::certs_renew_kubernetes_ca() {
  local ctx="$1"
  shift
  task::renew_kubernetes_ca "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 续期 etcd CA
# -----------------------------------------------------------------------------
module::certs_renew_etcd_ca() {
  local ctx="$1"
  shift
  task::renew_etcd_ca "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 续期 Kubernetes 叶子证书
# -----------------------------------------------------------------------------
module::certs_renew_kubernetes_certs() {
  local ctx="$1"
  shift
  task::renew_kubernetes_certs "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 续期 etcd 叶子证书
# -----------------------------------------------------------------------------
module::certs_renew_etcd_certs() {
  local ctx="$1"
  shift
  task::renew_etcd_certs "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 续期后重启服务（Kubernetes 组件）
# -----------------------------------------------------------------------------
module::certs_renew_and_restart_kubernetes() {
  local ctx="$1"
  shift
  task::renew_kubernetes_certs "${ctx}" "$@" || return $?
  logger::info "[Module:certs] Restarting Kubernetes components after cert renewal..."
  task::restart_kubernetes_after_cert_renew "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 续期后重启服务（ETCD 组件）
# -----------------------------------------------------------------------------
module::certs_renew_and_restart_etcd() {
  local ctx="$1"
  shift
  task::renew_etcd_certs "${ctx}" "$@" || return $?
  logger::info "[Module:certs] Restarting etcd after cert renewal..."
  task::restart_etcd_after_cert_renew "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 完整证书初始化流程
# -----------------------------------------------------------------------------
module::certs_init() {
  local ctx="$1"
  shift

  module::certs_collect_config "${ctx}" "$@" || return $?
  module::certs_init_node "${ctx}" "$@" || return $?
  module::certs_collect_cp "${ctx}" "$@" || return $?
  module::certs_collect_worker "${ctx}" "$@" || return $?
  module::certs_collect_etcd "${ctx}" "$@" || return $?
}

export -f module::check_tools
export -f module::certs_collect_config
export -f module::certs_init_node
export -f module::certs_collect_cp
export -f module::certs_collect_worker
export -f module::certs_collect_etcd
export -f module::certs_setup_auto_renew
export -f module::certs_init
export -f module::certs_renew_kubernetes_ca
export -f module::certs_renew_etcd_ca
export -f module::certs_renew_kubernetes_certs
export -f module::certs_renew_etcd_certs