#!/usr/bin/env bash
set -euo pipefail

# 配置依赖：统一在文件顶部加载
source "${KUBEXM_ROOT}/internal/logger/log.sh"
source "${KUBEXM_ROOT}/internal/config/config.sh"

identity::require_cluster_name() {
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*) cluster_name="${arg#*=}" ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  echo "${cluster_name}"
}

identity::resolve_node_name() {
  local node_name="" node
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
  echo "${node_name}"
}

identity::resolve_arch() {
  local node_name="$1"
  local arch
  arch=$(config::get_host_param "${node_name}" "arch")
  if [[ -z "${arch}" ]]; then
    arch=$(config::get_arch_list | awk -F',' '{print $1}')
  fi
  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
  esac
  if [[ -z "${arch}" ]]; then
    log::error "Failed to resolve arch for ${node_name}"
    return 1
  fi
  echo "${arch}"
}
