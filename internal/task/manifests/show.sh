#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Manifests Task - Show/Display
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::manifests_show_input_summary() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.show.input.summary:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_input_summary.sh"
}

task::manifests_show_defaults() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.show.defaults.header:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_defaults_header.sh" \
    "manifests.show.defaults.network:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_defaults_network.sh" \
    "manifests.show.defaults.cni:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_defaults_cni.sh" \
    "manifests.show.defaults.kube.proxy:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_defaults_kube_proxy.sh" \
    "manifests.show.defaults.storage:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_defaults_storage.sh" \
    "manifests.show.defaults.addons:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_defaults_addons.sh"
}

task::manifests_show_binaries() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.show.binaries:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_binaries.sh" \
    "manifests.show.runtime.binaries:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_runtime_binaries.sh"
}

task::manifests_show_images() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.show.images:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_images.sh"
}

task::manifests_show_helm() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.show.helm:${KUBEXM_ROOT}/internal/task/manifests/manifests_show_helm.sh"
}

export -f task::manifests_show_input_summary
export -f task::manifests_show_defaults
export -f task::manifests_show_binaries
export -f task::manifests_show_images
export -f task::manifests_show_helm