#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.join.worker.load.params::check() { return 1; }

step::kubeadm.join.worker.load.params::run() {
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

  local join_file="${KUBEXM_ROOT}/packages/${cluster_name}/kubeadm/join.env"
  if [[ ! -f "${join_file}" ]]; then
    log::error "Join parameters not found: ${join_file}"
    log::error "Please run kubeadm prepare join step first"
    return 1
  fi
  # shellcheck disable=SC1090
  source "${join_file}"
  local join_token="${JOIN_TOKEN:-}"
  local ca_hash="${CA_HASH:-}"
  local first_master_ip="${FIRST_MASTER_IP:-}"
  if [[ -z "${join_token}" || -z "${ca_hash}" ]]; then
    log::error "Invalid join parameters in ${join_file}"
    return 1
  fi

  context::set "kubeadm_join_worker_cluster_name" "${cluster_name}"
  context::set "kubeadm_join_worker_join_token" "${join_token}"
  context::set "kubeadm_join_worker_ca_hash" "${ca_hash}"
  context::set "kubeadm_join_worker_first_master_ip" "${first_master_ip}"
}

step::kubeadm.join.worker.load.params::rollback() { return 0; }

step::kubeadm.join.worker.load.params::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
