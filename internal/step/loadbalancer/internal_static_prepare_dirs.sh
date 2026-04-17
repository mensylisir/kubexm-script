#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.haproxy.static.prepare.dirs::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/etc/kubernetes/manifests"; then
    return 0  # dir exists, skip
  fi
  return 1  # need to create
}

step::lb.internal.haproxy.static.prepare.dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "mkdir -p /etc/kubernetes/manifests"
}

step::lb.internal.haproxy.static.prepare.dirs::rollback() { return 0; }

step::lb.internal.haproxy.static.prepare.dirs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
