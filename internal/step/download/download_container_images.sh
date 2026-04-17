#!/usr/bin/env bash
set -euo pipefail

step::download.container.images::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "container_images" && return 0
  return 1
}

step::download.container.images::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Downloading container images..."
  download::download_container_images "${DOWNLOAD_DIR}/images" "${DOWNLOAD_K8S_VERSION}" \
    "${DOWNLOAD_NETWORK_PLUGIN}" "${DOWNLOAD_K8S_TYPE}" "${DOWNLOAD_ETCD_TYPE}" \
    "${DOWNLOAD_LB_ENABLED}" "${DOWNLOAD_LB_MODE}" "${DOWNLOAD_LB_TYPE}"
  checkpoint::save "container_images"
}

step::download.container.images::rollback() { return 0; }

step::download.container.images::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
