#!/usr/bin/env bash
set -euo pipefail

step::cluster.delete.addon.dashboard::check() {
  if kubectl get deployment kubernetes-dashboard -n kubernetes-dashboard &>/dev/null; then
    return 1
  fi
  return 0
}

step::cluster.delete.addon.dashboard::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  log::info "Deleting kubernetes-dashboard deployment..."
  kubectl delete deployment kubernetes-dashboard -n kubernetes-dashboard >/dev/null 2>&1 || true
}

step::cluster.delete.addon.dashboard::rollback() { return 0; }

step::cluster.delete.addon.dashboard::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
