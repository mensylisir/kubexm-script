#!/usr/bin/env bash
set -euo pipefail

step::download.cni.plugins::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "cni_plugins" && return 0
  return 1
}

step::download.cni.plugins::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Downloading CNI plugins binaries..."
  local arch
  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Downloading CNI plugins for architecture: ${arch}"
    download::download_cni_binaries "${DOWNLOAD_DIR}/cni-plugins/${DOWNLOAD_CNI_VERSION}/${arch}" \
      "${DOWNLOAD_K8S_VERSION}" "${arch}"
  done
  checkpoint::save "cni_plugins"
}

step::download.cni.plugins::rollback() { return 0; }

step::download.cni.plugins::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
