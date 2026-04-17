#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kn.prepare.dirs::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # Check if both required directories exist on remote
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/etc/nginx" &&
     step::check::remote_dir_exists "${KUBEXM_HOST}" "/etc/keepalived"; then
    return 0  # dirs exist, skip
  fi
  return 1  # need to create
}

step::lb.external.kubexm.kn.prepare.dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "mkdir -p /etc/nginx /etc/keepalived"
}

step::lb.external.kubexm.kn.prepare.dirs::rollback() { return 0; }

step::lb.external.kubexm.kn.prepare.dirs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
