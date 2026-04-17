#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.fix.kubeconfig.permissions::check() {
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  local perms
  perms=$(runner::remote_exec "stat -c %a /etc/kubernetes/admin.conf 2>/dev/null" || echo "")
  if [[ "${perms}" == "600" ]]; then
    return 0
  fi
  return 1
}

step::kubernetes.fix.kubeconfig.permissions::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "chmod 600 /etc/kubernetes/*.conf /etc/kubernetes/*.kubeconfig >/dev/null 2>&1 || true"
}

step::kubernetes.fix.kubeconfig.permissions::rollback() { return 0; }

step::kubernetes.fix.kubeconfig.permissions::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
