#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.haproxy.systemd.render.service::check() {
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local node_name="${KUBEXM_HOST:-}"
  if [[ -z "${cluster_name}" || -z "${node_name}" ]]; then
    return 1
  fi
  local service_file="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/loadbalancer/internal-haproxy-systemd/haproxy.service"
  if [[ -f "${service_file}" ]]; then
    return 0
  fi
  return 1
}

step::lb.internal.haproxy.systemd.render.service::run() {
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

  local service_file
  service_file="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/loadbalancer/internal-haproxy-systemd/haproxy.service"
  mkdir -p "$(dirname "${service_file}")"

  if ! template::render "$(template::get_path "loadbalancer/haproxy/haproxy.service.tmpl")" "${service_file}"; then
    log::error "Failed to render haproxy service template"
    return 1
  fi
}

step::lb.internal.haproxy.systemd.render.service::rollback() { return 0; }

step::lb.internal.haproxy.systemd.render.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
