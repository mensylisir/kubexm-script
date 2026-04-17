#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Download Task - Main
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/infra/download/preflight.sh"
source "${KUBEXM_ROOT}/internal/task/infra/download/binaries.sh"
source "${KUBEXM_ROOT}/internal/task/infra/download/images.sh"
source "${KUBEXM_ROOT}/internal/task/infra/download/manifests.sh"

# 完整下载流程
task::download_resources() {
  local ctx="$1"
  shift
  task::download_check_deps "${ctx}" "$@"
  task::download_checkpoint_status "${ctx}" "$@"
  task::download_prepare_dirs "${ctx}" "$@"
  task::download_tools_binaries "${ctx}" "$@"
  task::download_kubernetes_binaries "${ctx}" "$@"
  task::download_cni_plugins "${ctx}" "$@"
  task::download_calicoctl "${ctx}" "$@"
  task::download_container_runtime "${ctx}" "$@"
  task::download_helm_binary "${ctx}" "$@"
  task::download_registry_binary "${ctx}" "$@"
  task::download_addon_manifests "${ctx}" "$@"
  task::download_container_images "${ctx}" "$@"
  task::download_helm_charts "${ctx}" "$@"
  task::download_helm_chart_images "${ctx}" "$@"
  task::download_addon_images "${ctx}" "$@"
  task::download_build_system_iso "${ctx}" "$@"
  task::download_generate_manifest "${ctx}" "$@"
  task::download_build_offline_resources "${ctx}" "$@"
}

export -f task::download_resources