#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: etcd.restart
# 重启 etcd 服务（配置变更后）
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

step::etcd.restart::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::etcd.restart "$@"
}

step::etcd.restart() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=etcd.restart] Restarting etcd..."

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart etcd" || { logger::error "[host=${host}] Failed to restart etcd"; return 1; }

  # 等待 etcd 启动
  local max_attempts=10
  local attempt=0
  while [[ ${attempt} -lt ${max_attempts} ]]; do
    if KUBEXM_HOST="${host}" runner::remote_exec "etcdctl endpoint health" &>/dev/null; then
      logger::info "[host=${host}] ETCD is healthy"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  logger::error "[host=${host}] ETCD failed to restart"
  return 1
}

step::etcd.restart::check() {
  # 配置变更后总是需要重启
  return 1
}

step::etcd.restart::rollback() { return 0; }

step::etcd.restart::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}
