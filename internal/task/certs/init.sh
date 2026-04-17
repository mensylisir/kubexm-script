#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Certs Task - Certificate Initialization
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# 证书配置目录
task::collect_certs_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.certs:${KUBEXM_ROOT}/internal/task/common/config/certs.sh"
}

# 初始化节点证书
task::init_node_certs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.node.certs.init:${KUBEXM_ROOT}/internal/task/common/node_certs_init.sh"
}

export -f task::collect_certs_config_dirs
export -f task::init_node_certs