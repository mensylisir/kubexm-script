#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Addons Task - Apply (reconfigure)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::apply_metrics_server() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "addon.apply.metrics.server:${KUBEXM_ROOT}/internal/step/addons/addon_apply.sh" \
    -- "metrics-server"
}

task::apply_ingress() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "addon.apply.ingress:${KUBEXM_ROOT}/internal/step/addons/addon_apply.sh" \
    -- "ingress"
}

task::apply_coredns() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "addon.apply.coredns:${KUBEXM_ROOT}/internal/step/addons/addon_apply.sh" \
    -- "coredns"
}

export -f task::apply_metrics_server
export -f task::apply_ingress
export -f task::apply_coredns
