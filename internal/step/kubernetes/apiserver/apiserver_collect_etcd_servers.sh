#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.apiserver.collect.etcd.servers::check() { return 1; }

step::kubernetes.apiserver.collect.etcd.servers::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local etcd_type
  etcd_type=$(config::get_etcd_type)
  local etcd_servers=""
  local external_endpoints
  external_endpoints=$(config::get_etcd_external_endpoints)
  if [[ -n "${external_endpoints}" ]]; then
    etcd_servers="${external_endpoints}"
  elif [[ "${etcd_type}" == "kubexm" ]]; then
    local endpoints=""
    for node in $(config::get_role_members 'etcd'); do
      local ip
      ip=$(config::get_host_param "${node}" "address")
      [[ -n "${ip}" ]] && endpoints+="https://${ip}:2379,"
    done
    etcd_servers="${endpoints%,}"
  elif [[ "${etcd_type}" == "exists" ]]; then
    log::error "etcd.type=exists requires spec.etcd.external_endpoints"
    return 1
  else
    etcd_servers="https://127.0.0.1:2379"
  fi
  if [[ -z "${etcd_servers}" ]]; then
    log::error "Failed to resolve etcd servers"
    return 1
  fi

  context::set "kubernetes_apiserver_etcd_servers" "${etcd_servers}"
}

step::kubernetes.apiserver.collect.etcd.servers::rollback() { return 0; }

step::kubernetes.apiserver.collect.etcd.servers::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
