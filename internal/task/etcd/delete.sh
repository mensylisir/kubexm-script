#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Etcd Task - Delete
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::delete_etcd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.stop:${KUBEXM_ROOT}/internal/step/kubexm/etcd/stop.sh" \
    "etcd.delete.files:${KUBEXM_ROOT}/internal/step/kubexm/etcd/delete_files.sh"
}

export -f task::delete_etcd