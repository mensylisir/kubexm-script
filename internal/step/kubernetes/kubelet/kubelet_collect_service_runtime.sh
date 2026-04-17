#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kubelet.collect.service.runtime::check() { return 1; }

step::kubernetes.kubelet.collect.service.runtime::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local runtime_type cri_socket
  runtime_type=$(config::get_runtime_type 2>/dev/null || echo "containerd")
  case "${runtime_type}" in
    containerd) cri_socket="unix:///run/containerd/containerd.sock" ;;
    docker)     cri_socket="unix:///var/run/cri-dockerd.sock" ;;
    crio)       cri_socket="unix:///var/run/crio/crio.sock" ;;
    *)          cri_socket="unix:///run/containerd/containerd.sock" ;;
  esac

  context::set "kubelet_service_cri_socket" "${cri_socket}"
}

step::kubernetes.kubelet.collect.service.runtime::rollback() { return 0; }

step::kubernetes.kubelet.collect.service.runtime::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
