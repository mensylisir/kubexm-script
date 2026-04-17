#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Download Task - Preflight (check deps, checkpoint, prepare dirs)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::download_check_deps() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.check.deps:${KUBEXM_ROOT}/internal/step/binary/download_check_deps.sh"
}

task::download_checkpoint_status() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.checkpoint.status:${KUBEXM_ROOT}/internal/step/binary/download_checkpoint_status.sh"
}

task::download_prepare_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.prepare.dirs:${KUBEXM_ROOT}/internal/step/binary/download_prepare_dirs.sh"
}

export -f task::download_check_deps
export -f task::download_checkpoint_status
export -f task::download_prepare_dirs