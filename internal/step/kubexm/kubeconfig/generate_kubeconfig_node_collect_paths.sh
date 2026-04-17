#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.generate.kubeconfig.node.collect.paths::check() { return 1; }

step::kubernetes.generate.kubeconfig.node.collect.paths::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local cluster_name
  cluster_name="$(context::get "kubeconfig_node_cluster_name" || true)"
  if [[ -z "${cluster_name}" ]]; then
    cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  fi

  local node_name=""
  local node
  for node in $(config::get_all_host_names); do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  if [[ -z "${node_name}" ]]; then
    node_name="${KUBEXM_HOST}"
  fi

  local cluster_dir="${KUBEXM_ROOT}/packages/${cluster_name}"
  local node_dir="${cluster_dir}/${node_name}"
  local pki_dir="${node_dir}/certs/kubernetes"
  local kube_dir="${node_dir}/kubeconfig"
  if [[ ! -d "${pki_dir}" ]]; then
    log::error "Missing PKI dir for ${node_name}: ${pki_dir}"
    return 1
  fi

  context::set "kubeconfig_node_cluster_name" "${cluster_name}"
  context::set "kubeconfig_node_name" "${node_name}"
  context::set "kubeconfig_node_pki_dir" "${pki_dir}"
  context::set "kubeconfig_node_dir" "${kube_dir}"
}

step::kubernetes.generate.kubeconfig.node.collect.paths::rollback() { return 0; }

step::kubernetes.generate.kubeconfig.node.collect.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
