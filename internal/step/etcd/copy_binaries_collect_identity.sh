#!/usr/bin/env bash
set -euo pipefail

step::etcd.copy.binaries.collect.identity::check() { return 1; }

step::etcd.copy.binaries.collect.identity::run() {
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

  local arch
  arch=$(config::get_host_param "${node_name}" "arch")
  if [[ -z "${arch}" ]]; then
    arch=$(config::get_arch_list | awk -F',' '{print $1}')
  fi
  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
  esac

  context::set "etcd_binaries_cluster_name" "${cluster_name}"
  context::set "etcd_binaries_node_name" "${node_name}"
  context::set "etcd_binaries_arch" "${arch}"
}

step::etcd.copy.binaries.collect.identity::rollback() { return 0; }

step::etcd.copy.binaries.collect.identity::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
