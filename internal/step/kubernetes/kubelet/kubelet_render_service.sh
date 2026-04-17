#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kubelet.render.service::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local service_dir
  service_dir="$(context::get "kubelet_service_dir" || true)"
  if [[ -n "${service_dir}" && -f "${service_dir}/kubelet.service" ]]; then
    return 0
  fi
  return 1
}

step::kubernetes.kubelet.render.service::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local cluster_name node_name cri_socket service_dir
  cluster_name="$(context::get "kubelet_service_cluster_name" || true)"
  node_name="$(context::get "kubelet_service_node_name" || true)"
  cri_socket="$(context::get "kubelet_service_cri_socket" || true)"
  service_dir="$(context::get "kubelet_service_dir" || true)"

  template::render_with_vars \
    "${KUBEXM_ROOT}/templates/kubernetes/kubelet/kubelet.service.tmpl" \
    "${service_dir}/kubelet.service" \
    "CLUSTER_NAME=${cluster_name}" \
    "NODE_NAME=${node_name}" \
    "CRI_SOCKET=${cri_socket}"
}

step::kubernetes.kubelet.render.service::rollback() { return 0; }

step::kubernetes.kubelet.render.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
