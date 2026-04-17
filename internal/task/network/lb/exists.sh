#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - exists (skip installation)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_lb_exists() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.exists:${KUBEXM_ROOT}/internal/step/loadbalancer/exists.sh"
}

export -f task::install_lb_exists