#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.runtime.collect::check() { return 1; }

step::cluster.render.runtime.collect::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
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

  local mode registry_host registry_port registry_addr registry_endpoint_scheme
  mode=$(config::get_mode)
  registry_host=$(config::get_registry_host)
  registry_port=$(config::get_registry_port)
  registry_addr="${registry_host}:${registry_port}"
  registry_endpoint_scheme="http"

  if [[ -z "${registry_host}" ]]; then
    if [[ "${mode}" == "offline" ]]; then
      log::error "Registry host is required in offline mode"
      return 1
    fi
    registry_addr="registry.k8s.io"
    registry_endpoint_scheme="https"
    log::warn "Registry host is empty, using public registry defaults in online mode"
  fi

  local runtime_type
  runtime_type=$(config::get_runtime_type)

  local all_nodes
  all_nodes=$(config::get_role_members 'control-plane')
  all_nodes="${all_nodes} $(config::get_role_members 'worker')"
  all_nodes=$(echo "${all_nodes}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

  context::set "runtime_registry_addr" "${registry_addr}"
  context::set "runtime_registry_scheme" "${registry_endpoint_scheme}"
  context::set "runtime_type" "${runtime_type}"
  context::set "runtime_nodes" "${all_nodes}"
}

step::cluster.render.runtime.collect::rollback() { return 0; }

step::cluster.render.runtime.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
