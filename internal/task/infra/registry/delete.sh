#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Registry Task - Delete
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# 删除 Registry
# -----------------------------------------------------------------------------
task::delete_registry() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "registry.delete:${KUBEXM_ROOT}/internal/step/registry/delete.sh"
}

export -f task::delete_registry