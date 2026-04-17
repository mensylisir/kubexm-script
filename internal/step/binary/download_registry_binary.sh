#!/usr/bin/env bash
set -euo pipefail

step::download.registry.binary::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context
  if [[ "${DOWNLOAD_REGISTRY_ENABLED}" != "true" ]]; then
    return 0
  fi
  checkpoint::is_done "registry_binary" && return 0
  return 1
}

step::download.registry.binary::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  if [[ "${DOWNLOAD_REGISTRY_ENABLED}" != "true" ]]; then
    log::info "Registry not enabled, skipping registry binary download"
    return 0
  fi

  log::info "Registry is enabled, downloading registry binary..."
  local arch
  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Downloading registry for architecture: ${arch}"
    download::download_registry_binary "${DOWNLOAD_DIR}/registry/${DOWNLOAD_REGISTRY_VERSION}/${arch}" \
      "${DOWNLOAD_REGISTRY_VERSION}" "${arch}"
  done
  checkpoint::save "registry_binary"
}

step::download.registry.binary::rollback() { return 0; }

step::download.registry.binary::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
