#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Runtime Task - cri-dockerd (docker-shim for containerd)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_cri_dockerd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "runtime.cri.dockerd.collect.arch:${KUBEXM_ROOT}/internal/step/runtime/docker/collect_arch.sh" \
    "runtime.cri.dockerd.collect.paths:${KUBEXM_ROOT}/internal/step/runtime/docker/collect_paths.sh" \
    "runtime.cri.dockerd.copy.binaries:${KUBEXM_ROOT}/internal/step/runtime/docker/copy_binaries.sh" \
    "runtime.cri.dockerd.systemd:${KUBEXM_ROOT}/internal/step/runtime/docker/systemd.sh"
}

task::delete_cri_dockerd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "runtime.cri.dockerd.stop:${KUBEXM_ROOT}/internal/step/runtime/docker/stop.sh" \
    "runtime.cri.dockerd.delete.files:${KUBEXM_ROOT}/internal/step/runtime/docker/delete_files.sh"
}

export -f task::install_cri_dockerd
export -f task::delete_cri_dockerd