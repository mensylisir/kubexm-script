#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Cluster Config Module
# ==============================================================================
# 集群级配置收集模块
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/common/config.sh"

module::cluster_collect_config() {
  local ctx="$1"
  shift
  task::collect_config_dirs "${ctx}" "$@"
}

export -f module::cluster_collect_config
