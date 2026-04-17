#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kube.proxy.collect.identity::check() { return 1; }

step::kubernetes.kube.proxy.collect.identity::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*) cluster_name="${arg#*=}" ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

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

  local config_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/kube-proxy"
  mkdir -p "${config_dir}"

  context::set "kube_proxy_cluster_name" "${cluster_name}"
  context::set "kube_proxy_node_name" "${node_name}"
  context::set "kube_proxy_config_dir" "${config_dir}"
}

step::kubernetes.kube.proxy.collect.identity::rollback() { return 0; }

step::kubernetes.kube.proxy.collect.identity::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
