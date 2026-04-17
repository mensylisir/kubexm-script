#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.pki.k8s.collect.pki.dir::check() { return 1; }

step::kubernetes.distribute.pki.k8s.collect.pki.dir::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local cluster_name node_name
  cluster_name=$(context::get "kubernetes_pki_cluster_name")
  node_name=$(context::get "kubernetes_pki_node_name")

  local pki_dir
  pki_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/certs/kubernetes"
  if [[ ! -d "${pki_dir}" ]]; then
    log::error "Missing PKI dir for ${node_name}: ${pki_dir}"
    return 1
  fi

  context::set "kubernetes_pki_dir" "${pki_dir}"
}

step::kubernetes.distribute.pki.k8s.collect.pki.dir::rollback() { return 0; }

step::kubernetes.distribute.pki.k8s.collect.pki.dir::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
