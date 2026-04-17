#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kube.proxy.render.service::check() {
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local node_name="${KUBEXM_HOST:-}"
  local service_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/kube-proxy"
  if [[ -f "${service_dir}/kube-proxy.service" ]]; then
    return 0
  fi
  return 1
}

step::kubernetes.kube.proxy.render.service::run() {
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
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

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

  local service_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/kube-proxy"
  mkdir -p "${service_dir}"

  template::render_with_vars \
    "${KUBEXM_ROOT}/templates/kubernetes/kube-proxy/kube-proxy.service.tmpl" \
    "${service_dir}/kube-proxy.service" \
    "CLUSTER_NAME=${cluster_name}"
}

step::kubernetes.kube.proxy.render.service::rollback() { return 0; }

step::kubernetes.kube.proxy.render.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
