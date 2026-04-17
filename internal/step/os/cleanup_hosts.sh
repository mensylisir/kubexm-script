#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os.cleanup_hosts
# 清理 /etc/hosts 中的 kubexm 管理条目（按集群名称区分）
# 删除集群时调用，如果节点不可达则跳过
# ==============================================================================

step::os.cleanup.hosts::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

  # 尝试 SSH 连接，如果失败则跳过
  if ! timeout 5 runner::remote_exec "echo ok" >/dev/null 2>&1; then
    return 0  # Node unreachable, skip
  fi

  # Check if there are kubexm entries for this cluster
  local cluster="${KUBEXM_CLUSTER_NAME:-default}"
  if runner::remote_exec "grep -q '# kubexm managed hosts - ${cluster}' /etc/hosts" 2>/dev/null; then
    return 1  # Need cleanup
  fi
  return 0  # Already cleaned up or no entries
}

step::os.cleanup.hosts::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local cluster="${KUBEXM_CLUSTER_NAME:-default}"

  # Remove kubexm managed section for this cluster
  runner::remote_exec "sed -i '/# kubexm managed hosts - ${cluster} - start/,/# kubexm managed hosts - ${cluster} - end/d' /etc/hosts 2>/dev/null || true"

  # Remove marker file
  runner::remote_exec "rm -f /etc/kubexm-hosts-${cluster}.marker"

  log::info "[hosts] kubexm entries removed from /etc/hosts on ${KUBEXM_HOST}"
}

step::os.cleanup.hosts::rollback() { return 0; }

step::os.cleanup.hosts::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_hosts
}
