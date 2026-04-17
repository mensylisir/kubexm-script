#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CNI Task - Apply
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::cni_apply() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cni.apply:${KUBEXM_ROOT}/internal/step/cni/apply.sh"
}

export -f task::cni_apply
