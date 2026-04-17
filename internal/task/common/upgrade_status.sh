#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.status::check() { return 1; }

step::cluster.upgrade.status::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  log::info "=== Checking upgrade status ==="
  log::info "Node status:"
  kubectl get nodes
  log::info "System components status:"
  kubectl get pods -n kube-system
  log::info "Cluster version:"
  kubectl version --short
  log::success "=== Upgrade status check completed ==="
}

step::cluster.upgrade.status::rollback() { return 0; }

step::cluster.upgrade.status::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
