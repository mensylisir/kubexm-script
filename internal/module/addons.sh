#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Addons Module
# ==============================================================================
# Addons 模块，包含：
# - metrics-server
# - ingress
# - coredns
# - etcd 自动备份
# - 证书自动续期
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/addons/metrics_server.sh"
source "${KUBEXM_ROOT}/internal/task/addons/ingress.sh"
source "${KUBEXM_ROOT}/internal/task/addons/coredns.sh"
source "${KUBEXM_ROOT}/internal/task/addons/etcd_backup.sh"
source "${KUBEXM_ROOT}/internal/task/addons/cert_auto_renew.sh"
source "${KUBEXM_ROOT}/internal/task/addons/apply.sh"

# -----------------------------------------------------------------------------
# 收集配置目录
# -----------------------------------------------------------------------------
module::addons_collect_config() {
  local ctx="$1"
  shift

  task::collect_metrics_server_config_dirs "${ctx}" "$@"
  task::collect_ingress_config_dirs "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 渲染配置
# -----------------------------------------------------------------------------
module::addons_render() {
  local ctx="$1"
  shift

  task::render_metrics_server "${ctx}" "$@"
  task::render_ingress "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 安装 Addons
# -----------------------------------------------------------------------------
module::addons_install() {
  local ctx="$1"
  shift

  task::install_metrics_server "${ctx}" "$@" || return $?
  task::install_ingress "${ctx}" "$@" || return $?
  task::install_coredns "${ctx}" "$@" || return $?
}

# -----------------------------------------------------------------------------
# 设置证书自动续期
# -----------------------------------------------------------------------------
module::addons_cert_renew_setup() {
  local ctx="$1"
  shift
  task::install_cert_auto_renew "${ctx}" "$@"
}

# Alias for pipeline compatibility
module::addons_cert_renew() {
  module::addons_cert_renew_setup "$@"
}

# -----------------------------------------------------------------------------
# 设置 etcd 自动备份
# -----------------------------------------------------------------------------
module::addons_etcd_backup_setup() {
  local ctx="$1"
  shift
  task::collect_etcd_backup_config "${ctx}" "$@" || return $?
  task::install_etcd_backup "${ctx}" "$@" || return $?
}

# Alias for pipeline compatibility
module::addons_etcd_backup() {
  module::addons_etcd_backup_setup "$@"
}

# -----------------------------------------------------------------------------
# 删除 Addons
# -----------------------------------------------------------------------------
module::addons_delete() {
  local ctx="$1"
  shift

  task::delete_metrics_server "${ctx}" "$@"
  task::delete_ingress "${ctx}" "$@"
  task::delete_coredns "${ctx}" "$@"
  task::delete_etcd_backup "${ctx}" "$@"
  task::delete_cert_auto_renew "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 仅重载配置（不重新安装）
# -----------------------------------------------------------------------------
module::addons_reconfigure() {
  local ctx="$1"
  shift

  logger::info "[Module:addons] Reconfiguring addons (render + apply)..."
  module::addons_render "${ctx}" "$@" || return $?

  # 重新应用各 addon manifest
  task::apply_metrics_server "${ctx}" "$@"
  task::apply_ingress "${ctx}" "$@"
  task::apply_coredns "${ctx}" "$@"
}

export -f module::addons_collect_config
export -f module::addons_render
export -f module::addons_install
export -f module::addons_cert_renew_setup
export -f module::addons_cert_renew
export -f module::addons_etcd_backup_setup
export -f module::addons_etcd_backup
export -f module::addons_delete
export -f module::addons_reconfigure