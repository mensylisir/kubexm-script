#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.generate.kubeconfig.node.collect.endpoint::check() { return 1; }

step::kubernetes.generate.kubeconfig.node.collect.endpoint::run() {
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
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local lb_enabled lb_mode
  lb_enabled=$(config::get_loadbalancer_enabled)
  lb_mode=$(config::get_loadbalancer_mode)

  local api_endpoint=""
  if [[ "${lb_enabled}" == "true" && "${lb_mode}" == "internal" ]]; then
    local worker_nodes
    worker_nodes="$(config::get_role_members 'worker')"
    local is_worker="false"
    local node node_ip
    for node in ${worker_nodes}; do
      node_ip=$(config::get_host_param "${node}" "address")
      if [[ -n "${node_ip}" && "${node_ip}" == "${KUBEXM_HOST}" ]]; then
        is_worker="true"
        break
      fi
    done
    if [[ "${is_worker}" == "true" ]]; then
      api_endpoint="127.0.0.1:6443"
    fi
  fi
  if [[ -z "${api_endpoint}" ]]; then
    api_endpoint=$(config::get_apiserver_endpoint)
  fi
  if [[ -z "${api_endpoint}" ]]; then
    local first_master
    first_master=$(config::get_role_members 'control-plane' | awk '{print $1}')
    api_endpoint=$(config::get_host_param "${first_master}" "address")
    api_endpoint="${api_endpoint}:6443"
  fi
  if [[ -z "${api_endpoint}" ]]; then
    log::error "Failed to resolve apiserver endpoint"
    return 1
  fi
  if [[ "${api_endpoint}" != https://* && "${api_endpoint}" != http://* ]]; then
    api_endpoint="https://${api_endpoint}"
  fi

  context::set "kubeconfig_node_api_endpoint" "${api_endpoint}"
}

step::kubernetes.generate.kubeconfig.node.collect.endpoint::rollback() { return 0; }

step::kubernetes.generate.kubeconfig.node.collect.endpoint::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
