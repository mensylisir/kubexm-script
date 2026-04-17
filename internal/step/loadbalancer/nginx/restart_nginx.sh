#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: lb.restart.nginx
# 重启 nginx（配置变更后）
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

step::lb.restart.nginx::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::lb.restart.nginx "$@"
}

step::lb.restart.nginx() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=lb.restart.nginx] Restarting nginx..."

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart nginx"

  logger::info "[host=${host} step=lb.restart.nginx] Nginx restarted"
  return 0
}

step::lb.restart.nginx::check() {
  # 配置变更后总是需要重启
  return 1
}

step::lb.restart.nginx::rollback() { return 0; }

step::lb.restart.nginx::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
