#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.apiserver.prepare.dirs::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::remote_exec "test -d /var/log/kubernetes"
}

step::kubernetes.apiserver.prepare.dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "mkdir -p /var/log/kubernetes"
}

step::kubernetes.apiserver.prepare.dirs::rollback() { return 0; }

step::kubernetes.apiserver.prepare.dirs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
