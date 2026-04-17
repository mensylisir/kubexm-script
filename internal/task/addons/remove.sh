#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Addons Task - Remove
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::addons::remove() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.delete.addon.ingress:${KUBEXM_ROOT}/internal/task/common/addon/delete_addon_ingress.sh" \
    "cluster.delete.addon.metrics.server:${KUBEXM_ROOT}/internal/task/common/addon/delete_addon_metrics_server.sh" \
    "cluster.delete.addon.dashboard:${KUBEXM_ROOT}/internal/task/common/addon/delete_addon_dashboard.sh" \
    "cluster.delete.addon.coredns:${KUBEXM_ROOT}/internal/task/common/addon/delete_addon_coredns.sh"
}

export -f task::addons::remove