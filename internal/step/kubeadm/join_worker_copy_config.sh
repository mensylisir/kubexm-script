#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.join.worker.copy.config::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # Check if kubeadm config already exists on remote
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/kubeadm-config.yaml"; then
    return 0  # already exists, skip
  fi
  return 1  # need to copy
}

step::kubeadm.join.worker.copy.config::run() {
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

  local config_file
  config_file="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/kubeadm-config.yaml"
  if [[ ! -f "${config_file}" ]]; then
    log::error "Missing kubeadm join config: ${config_file}"
    return 1
  fi

  runner::remote_exec "mkdir -p /etc/kubernetes"
  runner::remote_copy_file "${config_file}" "/etc/kubernetes/kubeadm-config.yaml"
}

step::kubeadm.join.worker.copy.config::rollback() { return 0; }

step::kubeadm.join.worker.copy.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
