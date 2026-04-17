#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Download Task - Binaries
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::download_tools_binaries() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.tools.binaries:${KUBEXM_ROOT}/internal/step/binary/download_tools_binaries.sh"
}

task::download_kubernetes_binaries() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.kubernetes.binaries:${KUBEXM_ROOT}/internal/step/binary/download_kubernetes_binaries.sh"
}

task::download_cni_plugins() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.cni.plugins:${KUBEXM_ROOT}/internal/step/binary/download_cni_plugins.sh"
}

task::download_calicoctl() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.calicoctl:${KUBEXM_ROOT}/internal/step/binary/download_calicoctl.sh"
}

task::download_container_runtime() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.container.runtime:${KUBEXM_ROOT}/internal/step/binary/download_container_runtime.sh"
}

task::download_helm_binary() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.helm.binary:${KUBEXM_ROOT}/internal/step/binary/download_helm_binary.sh"
}

task::download_registry_binary() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.registry.binary:${KUBEXM_ROOT}/internal/step/binary/download_registry_binary.sh"
}

export -f task::download_tools_binaries
export -f task::download_kubernetes_binaries
export -f task::download_cni_plugins
export -f task::download_calicoctl
export -f task::download_container_runtime
export -f task::download_helm_binary
export -f task::download_registry_binary