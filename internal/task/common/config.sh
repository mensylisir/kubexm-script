#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Cluster Task - Config Directories
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.collect:${KUBEXM_ROOT}/internal/task/common/config/collect.sh" \
    "cluster.config.dirs.cluster.root:${KUBEXM_ROOT}/internal/task/common/config/cluster_root.sh"
}

export -f task::collect_config_dirs