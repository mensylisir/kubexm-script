#!/usr/bin/env bash
set -euo pipefail

step::cni.calico.delete::check() {
  if kubectl get daemonset calico-node -n kube-system &>/dev/null; then
    return 1
  fi
  return 0
}

step::cni.calico.delete::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  log::info "Deleting Calico CNI..."
  kubectl delete daemonset calico-node -n kube-system >/dev/null 2>&1 || true
  kubectl delete deployment calico-kube-controllers -n kube-system >/dev/null 2>&1 || true
  kubectl delete namespace calico-system >/dev/null 2>&1 || true
  log::info "Calico CNI deleted"
}

step::cni.calico.delete::rollback() { return 0; }

step::cni.calico.delete::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}