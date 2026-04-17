#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.controller.manager.copy.service::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/systemd/system/kube-controller-manager.service"
}

step::kubernetes.controller.manager.copy.service::run() {
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
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

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

  local service_file="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/kube-controller-manager/kube-controller-manager.service"
  if [[ ! -f "${service_file}" ]]; then
    log::error "Missing kube-controller-manager service file: ${service_file}"
    return 1
  fi

  runner::remote_copy_file "${service_file}" "/etc/systemd/system/kube-controller-manager.service"
}

step::kubernetes.controller.manager.copy.service::rollback() { return 0; }

step::kubernetes.controller.manager.copy.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
