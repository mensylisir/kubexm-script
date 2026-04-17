#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Cluster Task - Smoke Test
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# Task: smoke_test - 集群冒烟测试
# -----------------------------------------------------------------------------
task::smoke_test() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.smoke.create.pod:${KUBEXM_ROOT}/internal/task/common/smoke/smoke_create_pod.sh" \
    "cluster.smoke.check.pod:${KUBEXM_ROOT}/internal/task/common/smoke/smoke_check_pod.sh" \
    "cluster.smoke.check.connectivity:${KUBEXM_ROOT}/internal/task/common/smoke/smoke_check_connectivity.sh" \
    "cluster.smoke.cleanup:${KUBEXM_ROOT}/internal/task/common/smoke/smoke_cleanup.sh"
}

export -f task::smoke_test