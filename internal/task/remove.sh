#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Cluster Workloads Task - Remove
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::cluster::workloads::remove() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.delete.namespace:${KUBEXM_ROOT}/internal/task/common/delete_namespace.sh" \
    "cluster.wait.workloads.deleted:${KUBEXM_ROOT}/internal/task/common/wait_workloads_deleted.sh"
}

export -f task::cluster::workloads::remove