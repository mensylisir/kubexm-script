#!/usr/bin/env bash
set -euo pipefail

step::cluster.reset.iptables::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # 如果节点不可达，跳过
  if ! step::check::host_reachable 5; then
    return 0
  fi
  return 1
}

step::cluster.reset.iptables::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X >/dev/null 2>&1 || true"
}

step::cluster.reset.iptables::rollback() { return 0; }

step::cluster.reset.iptables::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
