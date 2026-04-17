#!/usr/bin/env bash
set -euo pipefail

step::download.helm.chart.images::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "helm_chart_images" && return 0
  return 1
}

step::download.helm.chart.images::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Downloading Helm chart images..."
  download::download_helm_chart_images "${DOWNLOAD_DIR}/helm" "${DOWNLOAD_DIR}/images"
  checkpoint::save "helm_chart_images"
}

step::download.helm.chart.images::rollback() { return 0; }

step::download.helm.chart.images::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
