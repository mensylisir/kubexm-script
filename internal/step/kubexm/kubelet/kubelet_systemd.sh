#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kubelet.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "kubelet" 2>/dev/null; then
    return 0  # already running, skip
  fi
  return 1  # not running, need to start
}

step::kubernetes.kubelet.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl daemon-reload && systemctl enable kubelet && systemctl restart kubelet"
}

step::kubernetes.kubelet.systemd::rollback() { return 0; }

step::kubernetes.kubelet.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
