#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Task: TimeSync - 时间同步
# ==============================================================================
# 包含：
# - install_chrony
# - sync_time
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# 执行时间同步
# -----------------------------------------------------------------------------
task::time_sync() {
  local ctx="$1"
  shift

  task::run_steps "${ctx}" "$@" -- \
    "os.install.chrony:${KUBEXM_ROOT}/internal/step/os/install_chrony.sh" \
    "os.sync.time:${KUBEXM_ROOT}/internal/step/os/sync_time.sh"
}

export -f task::time_sync
