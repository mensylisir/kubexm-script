#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Etcd Module
# ==============================================================================
# Etcd 部署模块，包含：
# - 安装 etcd（配置/二进制/证书/服务）
# - 删除 etcd
# - 备份/恢复 etcd
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/etcd/install.sh"
source "${KUBEXM_ROOT}/internal/task/etcd/delete.sh"
source "${KUBEXM_ROOT}/internal/task/etcd/backup.sh"
source "${KUBEXM_ROOT}/internal/task/etcd/restart.sh"

# -----------------------------------------------------------------------------
# 安装 etcd
# -----------------------------------------------------------------------------
module::etcd_install() {
  local ctx="$1"
  shift
  task::install_etcd "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 删除 etcd
# -----------------------------------------------------------------------------
module::etcd_delete() {
  local ctx="$1"
  shift
  task::delete_etcd "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 备份 etcd
# -----------------------------------------------------------------------------
module::etcd_backup() {
  local ctx="$1"
  shift
  task::backup_etcd "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 恢复 etcd
# -----------------------------------------------------------------------------
module::etcd_restore() {
  local ctx="$1"
  shift
  task::restore_etcd "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 仅重载配置（不重新安装）
# -----------------------------------------------------------------------------
module::etcd_reconfigure() {
  local ctx="$1"
  shift

  logger::info "[Module:etcd] Reconfiguring etcd (render + restart)..."
  task::etcd_render_config "${ctx}" "$@" || return $?
  task::etcd_render_service "${ctx}" "$@" || return $?

  task::restart_etcd "${ctx}" "$@"
}

export -f module::etcd_install
export -f module::etcd_delete
export -f module::etcd_backup
export -f module::etcd_restore
export -f module::etcd_reconfigure