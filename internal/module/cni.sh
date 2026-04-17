#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CNI Module
# ==============================================================================
# CNI 插件安装模块，支持 calico / flannel / cilium
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/network/cni/calico.sh"
source "${KUBEXM_ROOT}/internal/task/network/cni/flannel.sh"
source "${KUBEXM_ROOT}/internal/task/network/cni/cilium.sh"
source "${KUBEXM_ROOT}/internal/task/network/cni/binaries.sh"
source "${KUBEXM_ROOT}/internal/task/network/cni/apply.sh"

# -----------------------------------------------------------------------------
# 收集配置目录
# -----------------------------------------------------------------------------
module::cni_collect_config() {
  local ctx="$1"
  shift

  local network_plugin
  network_plugin=$(config::get_network_plugin)

  case "${network_plugin}" in
    calico)  task::collect_calico_config_dirs  "${ctx}" "$@" ;;
    flannel) task::collect_flannel_config_dirs "${ctx}" "$@" ;;
    cilium)  task::collect_cilium_config_dirs  "${ctx}" "$@" ;;
  esac
}

# -----------------------------------------------------------------------------
# 渲染配置
# -----------------------------------------------------------------------------
module::cni_render() {
  local ctx="$1"
  shift

  local network_plugin
  network_plugin=$(config::get_network_plugin)

  case "${network_plugin}" in
    calico)  task::render_calico  "${ctx}" "$@" ;;
    flannel) task::render_flannel "${ctx}" "$@" ;;
    cilium)  task::render_cilium  "${ctx}" "$@" ;;
  esac
}

# -----------------------------------------------------------------------------
# 安装 CNI 二进制
# -----------------------------------------------------------------------------
module::cni_install_binaries() {
  local ctx="$1"
  shift
  task::install_cni_binaries "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 安装 CNI（自动选择）
# -----------------------------------------------------------------------------
module::cni_install() {
  local ctx="$1"
  shift

  local network_plugin
  network_plugin=$(config::get_network_plugin)

  case "${network_plugin}" in
    calico)  task::install_calico  "${ctx}" "$@" ;;
    flannel) task::install_flannel "${ctx}" "$@" ;;
    cilium)  task::install_cilium  "${ctx}" "$@" ;;
    *)
      echo "Unsupported CNI plugin: ${network_plugin}" >&2
      return 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 删除 CNI
# -----------------------------------------------------------------------------
module::cni_delete() {
  local ctx="$1"
  shift

  local network_plugin
  network_plugin=$(config::get_network_plugin)

  case "${network_plugin}" in
    calico)  task::delete_calico  "${ctx}" "$@" ;;
    flannel) task::delete_flannel "${ctx}" "$@" ;;
    cilium)  task::delete_cilium  "${ctx}" "$@" ;;
  esac
}

# -----------------------------------------------------------------------------
# 仅重载配置（不重新安装二进制）
# -----------------------------------------------------------------------------
module::cni_reconfigure() {
  local ctx="$1"
  shift

  logger::info "[Module:cni] Reconfiguring CNI (render + apply)..."
  module::cni_render "${ctx}" "$@" || return $?

  task::cni_apply "${ctx}" "$@"
}

export -f module::cni_collect_config
export -f module::cni_render
export -f module::cni_install_binaries
export -f module::cni_install
export -f module::cni_delete
export -f module::cni_reconfigure

# -----------------------------------------------------------------------------
# 升级 CNI
# -----------------------------------------------------------------------------
module::upgrade_cni() {
  local ctx="$1"
  shift
  task::upgrade_cni "${ctx}" "$@"
}

export -f module::upgrade_cni