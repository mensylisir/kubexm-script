#!/usr/bin/env bash
set -euo pipefail

step::download.container.runtime::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "container_runtime" && return 0
  return 1
}

step::download.container.runtime::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Downloading container runtime binaries..."
  local arch
  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Downloading ${DOWNLOAD_RUNTIME_TYPE} binaries for architecture: ${arch}"
    download::download_runtime_binaries \
      "${DOWNLOAD_DIR}/containerd/${DOWNLOAD_CONTAINERD_VERSION}/${arch}" \
      "${DOWNLOAD_DIR}/runc/${DOWNLOAD_RUNC_VERSION}/${arch}" \
      "${DOWNLOAD_DIR}/crictl/${DOWNLOAD_CRICTL_VERSION}/${arch}" \
      "${DOWNLOAD_RUNTIME_TYPE}" "${DOWNLOAD_K8S_VERSION}" "${arch}"
  done
  checkpoint::save "container_runtime"
}

step::download.container.runtime::rollback() { return 0; }

step::download.container.runtime::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
