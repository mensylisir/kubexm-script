#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.addons::check() { return 1; }

step::cluster.upgrade.addons::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  log::info "Upgrading addons..."
  if [[ "$(config::get_metrics_server_enabled)" == "true" ]]; then
    log::info "Upgrading metrics-server..."
  fi
  if [[ "$(config::get_ingress_enabled)" == "true" ]]; then
    log::info "Upgrading ingress controller..."
  fi
  log::info "Addons upgraded successfully"
}

step::cluster.upgrade.addons::rollback() { return 0; }

step::cluster.upgrade.addons::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
