#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Hosts Task - Cleanup
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::hosts::cleanup() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "os.cleanup.hosts:${KUBEXM_ROOT}/internal/step/os/cleanup_hosts.sh"
}

export -f task::hosts::cleanup