#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Etcd Task - Restart
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# Task: restart_etcd - 重启 etcd
# -----------------------------------------------------------------------------
task::restart_etcd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.restart:${KUBEXM_ROOT}/internal/step/kubexm/etcd/restart.sh"
}

export -f task::restart_etcd