#!/usr/bin/env bash
set -euo pipefail

step::manifests.collect.defaults::check() { return 1; }

step::manifests.collect.defaults::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local lb_enabled lb_mode lb_type
  lb_enabled="${KUBEXM_LB_ENABLED:-$(defaults::get_loadbalancer_enabled)}"
  lb_mode="${KUBEXM_LB_MODE:-$(defaults::get_loadbalancer_mode)}"
  lb_type="${KUBEXM_LB_TYPE:-$(defaults::get_loadbalancer_type)}"

  local addon_metrics_server addon_ingress addon_storage addon_nodelocaldns
  addon_metrics_server="false"
  addon_ingress="false"
  addon_storage="false"
  addon_nodelocaldns="false"

  context::set "manifests_lb_enabled" "${lb_enabled}"
  context::set "manifests_lb_mode" "${lb_mode}"
  context::set "manifests_lb_type" "${lb_type}"
  context::set "manifests_addon_metrics_server" "${addon_metrics_server}"
  context::set "manifests_addon_ingress" "${addon_ingress}"
  context::set "manifests_addon_storage" "${addon_storage}"
  context::set "manifests_addon_nodelocaldns" "${addon_nodelocaldns}"
}

step::manifests.collect.defaults::rollback() { return 0; }

step::manifests.collect.defaults::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
