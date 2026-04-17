#!/usr/bin/env bash
set -euo pipefail

step::download.kubernetes.binaries::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "kubernetes_binaries" && return 0
  return 1
}

step::download.kubernetes.binaries::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  log::info "Downloading Kubernetes binaries (${DOWNLOAD_K8S_TYPE} mode)..."
  download::download_kubernetes_binaries "${DOWNLOAD_DIR}/kubernetes/${DOWNLOAD_K8S_VERSION}" \
    "${DOWNLOAD_K8S_VERSION}" "${DOWNLOAD_ARCH_LIST}" "${DOWNLOAD_K8S_TYPE}" "${DOWNLOAD_ETCD_TYPE}"
  checkpoint::save "kubernetes_binaries"
}

step::download.kubernetes.binaries::rollback() { return 0; }

step::download.kubernetes.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
