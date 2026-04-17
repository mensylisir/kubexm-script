#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Runtime Task - Restart
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# Task: restart_runtime - 重启运行时服务
# -----------------------------------------------------------------------------
task::restart_runtime() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "runtime.restart.service:${KUBEXM_ROOT}/internal/step/runtime/restart_service.sh"
}

export -f task::restart_runtime