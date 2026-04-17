#!/usr/bin/env bash
set -euo pipefail

step::cni.flannel.delete::check() {
  if kubectl get daemonset kube-flannel-ds -n kube-flannel &>/dev/null; then
    return 1
  fi
  return 0
}

step::cni.flannel.delete::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  log::info "Deleting Flannel CNI..."
  kubectl delete daemonset kube-flannel-ds -n kube-flannel >/dev/null 2>&1 || true
  kubectl delete namespace kube-flannel >/dev/null 2>&1 || true
  log::info "Flannel CNI deleted"
}

step::cni.flannel.delete::rollback() { return 0; }

step::cni.flannel.delete::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}