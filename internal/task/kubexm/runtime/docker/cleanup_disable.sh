#!/usr/bin/env bash
set -euo pipefail

step::cluster.cleanup.runtime.docker.disable::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # 如果节点不可达，跳过
  if ! step::check::host_reachable 5; then
    return 0
  fi
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  if runner::remote_exec "systemctl is-enabled --quiet docker" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

step::cluster.cleanup.runtime.docker.disable::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl is-enabled --quiet docker >/dev/null 2>&1 && systemctl disable docker >/dev/null 2>&1 || true"
}

step::cluster.cleanup.runtime.docker.disable::rollback() { return 0; }

step::cluster.cleanup.runtime.docker.disable::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
