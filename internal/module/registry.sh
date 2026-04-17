#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Registry Module
# ==============================================================================
# Registry 部署模块，包含：
# - 创建 Registry
# - 删除 Registry
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/infra/registry/create.sh"
source "${KUBEXM_ROOT}/internal/task/infra/registry/delete.sh"

# -----------------------------------------------------------------------------
# 工具检查
# -----------------------------------------------------------------------------
module::check_tools() {
  local ctx="$1"
  shift
  task::check_tools "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 创建 Registry
# -----------------------------------------------------------------------------
module::registry_create() {
  local ctx="$1"
  shift
  task::create_registry "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 删除 Registry
# -----------------------------------------------------------------------------
module::registry_delete() {
  local ctx="$1"
  shift
  task::delete_registry "${ctx}" "$@"
}

export -f module::check_tools
export -f module::registry_create
export -f module::registry_delete