#!/usr/bin/env bash
set -euo pipefail

step::registry.create.collect.role::check() { return 1; }

step::registry.create.collect.role::run() {
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
    echo "missing required --cluster for create registry" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local registry_enabled
  registry_enabled=$(config::get_registry_enabled)
  if [[ "${registry_enabled}" != "true" ]]; then
    log::error "Registry is not enabled in config.yaml"
    return 1
  fi

  local registry_nodes
  registry_nodes=$(config::get_role_members 'registry')
  if [[ -z "${registry_nodes}" ]]; then
    log::error "No registry nodes found in host.yaml"
    return 1
  fi

  local node_name=""
  local node
  for node in ${registry_nodes}; do
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

  context::set "registry_create_cluster_name" "${cluster_name}"
  context::set "registry_create_node_name" "${node_name}"
}

step::registry.create.collect.role::rollback() { return 0; }

step::registry.create.collect.role::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
