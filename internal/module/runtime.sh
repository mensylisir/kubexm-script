#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Runtime Module
# ==============================================================================
# 容器运行时模块，按组件分割 task：
# - containerd: task::install_containerd, task::delete_containerd
# - docker: task::install_docker, task::delete_docker
# - crio: task::install_crio, task::delete_crio
# - cri_dockerd: task::install_cri_dockerd, task::delete_cri_dockerd
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/runtime/containerd.sh"
source "${KUBEXM_ROOT}/internal/task/runtime/docker.sh"
source "${KUBEXM_ROOT}/internal/task/runtime/crio.sh"
source "${KUBEXM_ROOT}/internal/task/runtime/cri_dockerd.sh"
source "${KUBEXM_ROOT}/internal/task/runtime/restart.sh"

# -----------------------------------------------------------------------------
# 收集运行时配置目录
# -----------------------------------------------------------------------------
module::runtime_collect_config() {
  local ctx="$1"
  shift

  local runtime_type
  runtime_type=$(config::get_runtime_type)

  case "${runtime_type}" in
    containerd) task::collect_containerd_config_dirs "${ctx}" "$@" ;;
    docker)     task::collect_docker_config_dirs "${ctx}" "$@" ;;
    crio)       task::collect_crio_config_dirs "${ctx}" "$@" ;;
    cri_dockerd)
      # cri_dockerd doesn't use config dirs - it's a docker shim installed alongside containerd
      logger::debug "cri_dockerd doesn't require config dir collection"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 渲染运行时配置
# -----------------------------------------------------------------------------
module::runtime_render() {
  local ctx="$1"
  shift

  local runtime_type
  runtime_type=$(config::get_runtime_type)

  case "${runtime_type}" in
    containerd) task::render_containerd "${ctx}" "$@" ;;
    docker)     task::render_docker "${ctx}" "$@" ;;
    crio)       task::render_crio "${ctx}" "$@" ;;
    cri_dockerd)
      # cri_dockerd doesn't render its own config - it's a docker shim for containerd
      logger::debug "cri_dockerd doesn't require config rendering"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 安装运行时
# -----------------------------------------------------------------------------
module::runtime_install() {
  local ctx="$1"
  shift

  local runtime_type
  runtime_type=$(config::get_runtime_type)

  case "${runtime_type}" in
    containerd) task::install_containerd "${ctx}" "$@" ;;
    docker)     task::install_docker "${ctx}" "$@" ;;
    crio)       task::install_crio "${ctx}" "$@" ;;
    cri_dockerd) task::install_cri_dockerd "${ctx}" "$@" ;;
    *)
      logger::error "Unsupported runtime type: ${runtime_type}"
      return 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 删除运行时
# -----------------------------------------------------------------------------
module::runtime_delete() {
  local ctx="$1"
  shift

  local runtime_type
  runtime_type=$(config::get_runtime_type)

  case "${runtime_type}" in
    containerd) task::delete_containerd "${ctx}" "$@" ;;
    docker)     task::delete_docker "${ctx}" "$@" ;;
    crio)       task::delete_crio "${ctx}" "$@" ;;
    cri_dockerd) task::delete_cri_dockerd "${ctx}" "$@" ;;
  esac
}

# -----------------------------------------------------------------------------
# 仅重载配置（不重新安装二进制）
# -----------------------------------------------------------------------------
module::runtime_reconfigure() {
  local ctx="$1"
  shift

  logger::info "[Module:runtime] Reconfiguring runtime..."
  module::runtime_render "${ctx}" "$@" || return $?

  # 重启运行时服务（通用 step，内部根据 runtime type 处理）
  task::restart_runtime "${ctx}" "$@"
}

export -f module::runtime_collect_config
export -f module::runtime_render
export -f module::runtime_install
export -f module::runtime_delete
export -f module::runtime_reconfigure