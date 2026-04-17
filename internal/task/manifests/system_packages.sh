#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Manifests Task - System Packages
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::manifests_collect_system_packages() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.collect.system.packages:${KUBEXM_ROOT}/internal/task/manifests/manifests_collect_system_packages.sh"
}

task::manifests_show_system_packages() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.show.system.packages.header:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_system_packages_header.sh" \
    "manifests.show.system.packages.rpm:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_system_packages_rpm.sh" \
    "manifests.show.system.packages.deb:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_system_packages_deb.sh" \
    "manifests.show.system.packages.ha:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_system_packages_ha.sh" \
    "manifests.show.system.packages.storage:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_system_packages_storage.sh"
}

export -f task::manifests_collect_system_packages
export -f task::manifests_show_system_packages