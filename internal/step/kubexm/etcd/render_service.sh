#!/usr/bin/env bash
set -euo pipefail

step::etcd.render.service::check() {
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local node_name="${KUBEXM_HOST:-}"
  if [[ -z "${cluster_name}" || -z "${node_name}" ]]; then
    return 1
  fi
  local etcd_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/etcd"
  if [[ -f "${etcd_dir}/etcd.service" ]]; then
    return 0
  fi
  return 1
}

step::etcd.render.service::run() {
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
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/utils/etcd_render.sh"

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

  local etcd_dir
  etcd_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/etcd"
  mkdir -p "${etcd_dir}"

  etcd::generate_service "${node_name}" "${etcd_dir}"
}

step::etcd.render.service::rollback() { return 0; }

step::etcd.render.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
