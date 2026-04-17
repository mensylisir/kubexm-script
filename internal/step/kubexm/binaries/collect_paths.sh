#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.binaries.kubexm.collect.paths::check() { return 1; }

step::kubernetes.distribute.binaries.kubexm.collect.paths::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local arch
  arch="$(context::get "kubernetes_kubexm_binaries_arch" || true)"

  local k8s_version
  k8s_version=$(config::get_kubernetes_version)

  local base_dir
  base_dir="${KUBEXM_ROOT}/packages/kubernetes/${k8s_version}/${arch}"
  if [[ ! -d "${base_dir}" ]]; then
    log::error "Kubernetes binaries not found: ${base_dir}"
    return 1
  fi

  local components=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "kubelet" "kubectl" "kube-proxy")

  context::set "kubernetes_kubexm_binaries_base_dir" "${base_dir}"
  context::set "kubernetes_kubexm_binaries_components" "${components[*]}"
}

step::kubernetes.distribute.binaries.kubexm.collect.paths::rollback() { return 0; }

step::kubernetes.distribute.binaries.kubexm.collect.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
