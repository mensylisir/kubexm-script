#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.generate.kubeconfig.node.generate::check() { return 1; }

step::kubernetes.generate.kubeconfig.node.generate::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/kubeconfig.sh"

  local api_endpoint kube_dir pki_dir node_name
  api_endpoint="$(context::get "kubeconfig_node_api_endpoint" || true)"
  kube_dir="$(context::get "kubeconfig_node_dir" || true)"
  pki_dir="$(context::get "kubeconfig_node_pki_dir" || true)"
  node_name="$(context::get "kubeconfig_node_name" || true)"

  kubeconfig::generate_all "${kube_dir}" "${api_endpoint}" "${pki_dir}" "${node_name}" "kubexm"
}

step::kubernetes.generate.kubeconfig.node.generate::rollback() { return 0; }

step::kubernetes.generate.kubeconfig.node.generate::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
