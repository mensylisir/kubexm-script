#!/usr/bin/env bash
set -euo pipefail

step::download.calicoctl::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context
  if [[ "${DOWNLOAD_NETWORK_PLUGIN}" != "calico" ]]; then
    return 0
  fi
  checkpoint::is_done "calicoctl" && return 0
  return 1
}

step::download.calicoctl::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  if [[ "${DOWNLOAD_NETWORK_PLUGIN}" != "calico" ]]; then
    return 0
  fi

  log::info "Downloading calicoctl binaries..."
  local arch
  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Downloading calicoctl for architecture: ${arch}"
    download::download_calicoctl_binary "${DOWNLOAD_DIR}/calicoctl/${DOWNLOAD_CALICO_VERSION}/${arch}" \
      "${DOWNLOAD_K8S_VERSION}" "${arch}"
  done
  checkpoint::save "calicoctl"
}

step::download.calicoctl::rollback() { return 0; }

step::download.calicoctl::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
