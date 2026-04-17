#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: Reset kubexm services (stop and disable all kubernetes component services)
# ==============================================================================

step::cluster.reset.kubexm.services::check() { return 1; }

step::cluster.reset.kubexm.services::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Stopping kubexm kubernetes component services..."

  # List of kubexm component services to stop
  local services=(
    "kube-apiserver"
    "kube-controller-manager"
    "kube-scheduler"
    "kubelet"
    "kube-proxy"
  )

  for service in "${services[@]}"; do
    log::info "Stopping and disabling ${service}..."
    runner::remote_exec "systemctl stop ${service}.service || true" || \
      log::warn "Failed to stop ${service} on ${KUBEXM_HOST}"
    runner::remote_exec "systemctl disable ${service}.service || true" || \
      log::warn "Failed to disable ${service} on ${KUBEXM_HOST}"
    runner::remote_exec "rm -f /etc/systemd/system/${service}.service || true" || \
      log::warn "Failed to remove systemd unit for ${service} on ${KUBEXM_HOST}"
  done

  # Reload systemd daemon
  runner::remote_exec "systemctl daemon-reload || true" || \
    log::warn "Failed to reload systemd daemon on ${KUBEXM_HOST}"

  log::info "All kubexm services stopped and disabled"
}

step::cluster.reset.kubexm.services::rollback() { return 0; }

step::cluster.reset.kubexm.services::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
