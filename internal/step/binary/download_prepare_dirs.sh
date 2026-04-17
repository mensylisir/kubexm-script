#!/usr/bin/env bash
set -euo pipefail

step::download.prepare.dirs::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "prepare_dirs" && return 0
  return 1
}

step::download.prepare.dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Creating package directory structure..."

  local arch
  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Creating: ${DOWNLOAD_DIR}/kubernetes/${DOWNLOAD_K8S_VERSION}/${arch}"
    mkdir -p "${DOWNLOAD_DIR}/kubernetes/${DOWNLOAD_K8S_VERSION}/${arch}"
  done

  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Creating: ${DOWNLOAD_DIR}/containerd/${DOWNLOAD_CONTAINERD_VERSION}/${arch}"
    mkdir -p "${DOWNLOAD_DIR}/containerd/${DOWNLOAD_CONTAINERD_VERSION}/${arch}"
  done

  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Creating: ${DOWNLOAD_DIR}/runc/${DOWNLOAD_RUNC_VERSION}/${arch}"
    mkdir -p "${DOWNLOAD_DIR}/runc/${DOWNLOAD_RUNC_VERSION}/${arch}"
  done

  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Creating: ${DOWNLOAD_DIR}/crictl/${DOWNLOAD_CRICTL_VERSION}/${arch}"
    mkdir -p "${DOWNLOAD_DIR}/crictl/${DOWNLOAD_CRICTL_VERSION}/${arch}"
  done

  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Creating: ${DOWNLOAD_DIR}/cni-plugins/${DOWNLOAD_CNI_VERSION}/${arch}"
    mkdir -p "${DOWNLOAD_DIR}/cni-plugins/${DOWNLOAD_CNI_VERSION}/${arch}"
  done

  if [[ "${DOWNLOAD_NETWORK_PLUGIN}" == "calico" ]]; then
    for arch in ${DOWNLOAD_ARCH_LIST}; do
      log::info "  Creating: ${DOWNLOAD_DIR}/calicoctl/${DOWNLOAD_CALICO_VERSION}/${arch}"
      mkdir -p "${DOWNLOAD_DIR}/calicoctl/${DOWNLOAD_CALICO_VERSION}/${arch}"
    done
  fi

  log::info "  Creating: ${DOWNLOAD_DIR}/images"
  mkdir -p "${DOWNLOAD_DIR}/images"

  log::info "  Creating: ${DOWNLOAD_DIR}/helm"
  mkdir -p "${DOWNLOAD_DIR}/helm"

  log::info "  Creating: ${DOWNLOAD_DIR}/iso"
  mkdir -p "${DOWNLOAD_DIR}/iso"

  for arch in ${DOWNLOAD_ARCH_LIST}; do
    log::info "  Creating: ${DOWNLOAD_DIR}/tools/common/${arch}"
    mkdir -p "${DOWNLOAD_DIR}/tools/common/${arch}"
  done

  checkpoint::save "prepare_dirs"
}

step::download.prepare.dirs::rollback() { return 0; }

step::download.prepare.dirs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
