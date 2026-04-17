#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# OS Module
# ==============================================================================
# OS 级别操作模块，包含：
# - hosts 更新
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/common/scale_hosts.sh"

# -----------------------------------------------------------------------------
# 更新 /etc/hosts
# -----------------------------------------------------------------------------
module::os_update_hosts() {
  local ctx="$1"
  shift
  task::scale_update_hosts "${ctx}" "$@"
}

export -f module::os_update_hosts