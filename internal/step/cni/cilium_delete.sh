#!/usr/bin/env bash
set -euo pipefail

step::cni.cilium.delete::check() {
  if kubectl get daemonset cilium -n kube-system &>/dev/null; then
    return 1
  fi
  return 0
}

step::cni.cilium.delete::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  log::info "Deleting Cilium CNI..."
  if command -v helm &>/dev/null; then
    helm uninstall cilium -n kube-system >/dev/null 2>&1 || true
  else
    kubectl delete daemonset cilium -n kube-system >/dev/null 2>&1 || true
    kubectl delete deployment cilium-operator -n kube-system >/dev/null 2>&1 || true
  fi
  kubectl delete namespace cilium-system >/dev/null 2>&1 || true
  log::info "Cilium CNI deleted"
}

step::cni.cilium.delete::rollback() { return 0; }

step::cni.cilium.delete::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}