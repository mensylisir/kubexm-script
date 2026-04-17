#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Manifests Task - Main
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/manifests/collect.sh"
source "${KUBEXM_ROOT}/internal/task/manifests/show.sh"
source "${KUBEXM_ROOT}/internal/task/manifests/system_packages.sh"

task::manifests() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::manifests_collect "${ctx}" "${args[@]}"
  task::manifests_show_input_summary "${ctx}" "${args[@]}"
  task::manifests_show_defaults "${ctx}" "${args[@]}"
  task::manifests_show_binaries "${ctx}" "${args[@]}"
  task::manifests_show_images "${ctx}" "${args[@]}"
  task::manifests_show_helm "${ctx}" "${args[@]}"
  task::manifests_collect_system_packages "${ctx}" "${args[@]}"
  task::manifests_show_system_packages "${ctx}" "${args[@]}"
  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.show.paths:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_paths.sh"
}

export -f task::manifests