#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: lb.restart.keepalived
# 重启 keepalived（配置变更后）
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

step::lb.restart.keepalived::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::lb.restart.keepalived "$@"
}

step::lb.restart.keepalived() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=lb.restart.keepalived] Restarting keepalived..."

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart keepalived"

  logger::info "[host=${host} step=lb.restart.keepalived] Keepalived restarted"
  return 0
}

step::lb.restart.keepalived::check() {
  # 配置变更后总是需要重启
  return 1
}

step::lb.restart.keepalived::rollback() { return 0; }

step::lb.restart.keepalived::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
