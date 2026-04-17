#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Health Check Module
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# 全部健康检查
# -----------------------------------------------------------------------------
task::health_check_all() {
  local ctx="$1"
  shift

  task::health_check_nodes "${ctx}" "$@" || return $?
  task::health_check_components "${ctx}" "$@" || return $?
  task::health_check_workloads "${ctx}" "$@" || return $?
  task::health_check_connectivity "${ctx}" "$@" || return $?

  logger::info "[Health] All health checks passed!"
  return 0
}

# -----------------------------------------------------------------------------
# 节点健康检查
# -----------------------------------------------------------------------------
task::health_check_nodes() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "health.check.nodes:${KUBEXM_ROOT}/internal/task/common/health_check_nodes.sh"
}

# -----------------------------------------------------------------------------
# 组件健康检查
# -----------------------------------------------------------------------------
task::health_check_components() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "health.check.components:${KUBEXM_ROOT}/internal/task/common/health_check_components.sh"
}

# -----------------------------------------------------------------------------
# 工作负载健康检查
# -----------------------------------------------------------------------------
task::health_check_workloads() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "health.check.workloads:${KUBEXM_ROOT}/internal/task/common/health_check_workloads.sh"
}

# -----------------------------------------------------------------------------
# 连接性检查
# -----------------------------------------------------------------------------
task::health_check_connectivity() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "health.check.connectivity:${KUBEXM_ROOT}/internal/task/common/health_check_connectivity.sh"
}

export -f task::health_check_all
export -f task::health_check_nodes
export -f task::health_check_components
export -f task::health_check_workloads
export -f task::health_check_connectivity
