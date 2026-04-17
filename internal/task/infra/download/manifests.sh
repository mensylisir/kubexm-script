#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Download Task - Manifests and Offline Resources
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::download_addon_manifests() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.addon.manifests:${KUBEXM_ROOT}/internal/step/binary/download_addon_manifests.sh"
}

task::download_build_system_iso() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.build.system.iso:${KUBEXM_ROOT}/internal/step/binary/download_build_system_iso.sh"
}

task::download_generate_manifest() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.generate.manifest:${KUBEXM_ROOT}/internal/step/binary/download_generate_manifest.sh"
}

task::download_build_offline_resources() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.build.offline.resources:${KUBEXM_ROOT}/internal/step/binary/download_build_offline_resources.sh"
}

export -f task::download_addon_manifests
export -f task::download_build_system_iso
export -f task::download_generate_manifest
export -f task::download_build_offline_resources