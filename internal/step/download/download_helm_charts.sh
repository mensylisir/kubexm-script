#!/usr/bin/env bash
set -euo pipefail

step::download.helm.charts::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "helm_charts" && return 0
  return 1
}

step::download.helm.charts::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Downloading Helm charts..."
  download::download_helm_charts "${DOWNLOAD_DIR}/helm"
  checkpoint::save "helm_charts"
}

step::download.helm.charts::rollback() { return 0; }

step::download.helm.charts::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
