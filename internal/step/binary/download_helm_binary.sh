#!/usr/bin/env bash
set -euo pipefail

step::download.helm.binary::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "helm_binary" && return 0
  return 1
}

step::download.helm.binary::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Downloading Helm binary..."
  local arch
  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Downloading helm for architecture: ${arch}"
    download::download_helm_binary "${DOWNLOAD_DIR}/helm/${DOWNLOAD_HELM_VERSION}/${arch}" \
      "${DOWNLOAD_K8S_VERSION}" "${arch}"
  done
  checkpoint::save "helm_binary"
}

step::download.helm.binary::rollback() { return 0; }

step::download.helm.binary::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
