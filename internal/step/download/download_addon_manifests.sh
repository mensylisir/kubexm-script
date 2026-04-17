#!/usr/bin/env bash
set -euo pipefail

step::download.addon.manifests::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "addon_manifests" && return 0
  return 1
}

step::download.addon.manifests::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Downloading addon manifests (CNI YAML)..."
  download::download_addon_manifests "${DOWNLOAD_DIR}" "${DOWNLOAD_K8S_VERSION}" "${DOWNLOAD_NETWORK_PLUGIN}"
  checkpoint::save "addon_manifests"
}

step::download.addon.manifests::rollback() { return 0; }

step::download.addon.manifests::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
