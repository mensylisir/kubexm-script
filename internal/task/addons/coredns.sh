#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Addon Task - coredns
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_coredns() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.addon.coredns:${KUBEXM_ROOT}/internal/task/common/addon/install_addon_coredns.sh"
}

task::delete_coredns() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.delete.addon.coredns:${KUBEXM_ROOT}/internal/task/common/addon/delete_addon_coredns.sh"
}

export -f task::install_coredns
export -f task::delete_coredns