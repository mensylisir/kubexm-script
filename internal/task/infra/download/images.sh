#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Download Task - Images
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::download_container_images() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.container.images:${KUBEXM_ROOT}/internal/step/binary/download_container_images.sh"
}

task::download_helm_charts() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.helm.charts:${KUBEXM_ROOT}/internal/step/binary/download_helm_charts.sh"
}

task::download_helm_chart_images() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.helm.chart.images:${KUBEXM_ROOT}/internal/step/binary/download_helm_chart_images.sh"
}

task::download_addon_images() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "download.addon.images:${KUBEXM_ROOT}/internal/step/binary/download_addon_images.sh"
}

export -f task::download_container_images
export -f task::download_helm_charts
export -f task::download_helm_chart_images
export -f task::download_addon_images