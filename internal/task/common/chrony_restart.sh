#!/usr/bin/env bash
set -euo pipefail

step::cluster.chrony.restart::check() {
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  if runner::remote_exec "systemctl is-active --quiet chronyd" >/dev/null 2>&1; then
    if runner::remote_exec "systemctl is-enabled --quiet chronyd" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

step::cluster.chrony.restart::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::remote_exec "systemctl restart chronyd && systemctl enable chronyd"
}

step::cluster.chrony.restart::rollback() { return 0; }

step::cluster.chrony.restart::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_hosts
}
