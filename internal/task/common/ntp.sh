#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Cluster Task - NTP Configuration
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::configure_chrony() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.chrony.collect.config:${KUBEXM_ROOT}/internal/task/common/chrony_collect_config.sh" \
    "cluster.chrony.copy.config:${KUBEXM_ROOT}/internal/task/common/chrony_copy_config.sh" \
    "cluster.chrony.restart:${KUBEXM_ROOT}/internal/task/common/chrony_restart.sh"
}

export -f task::configure_chrony