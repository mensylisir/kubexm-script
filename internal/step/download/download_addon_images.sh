#!/usr/bin/env bash
set -euo pipefail

step::download.addon.images::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context
  if [[ ! -f "${DOWNLOAD_DIR}/addon-images.list" ]]; then
    return 0
  fi
  checkpoint::is_done "addon_images" && return 0
  return 1
}

step::download.addon.images::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  if [[ ! -f "${DOWNLOAD_DIR}/addon-images.list" ]]; then
    return 0
  fi

  log::info "Downloading addon manifest images..."
  download::download_images_from_list "${DOWNLOAD_DIR}/addon-images.list" "${DOWNLOAD_DIR}/images"
  checkpoint::save "addon_images"
}

step::download.addon.images::rollback() { return 0; }

step::download.addon.images::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
