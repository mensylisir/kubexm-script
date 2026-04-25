#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.generate.kubeconfig.global::check() {
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local cluster_dir="${KUBEXM_ROOT}/packages/${cluster_name}"
  local global_kubeconfig="${cluster_dir}/kubeconfig/admin.conf"
  if [[ -f "${global_kubeconfig}" ]]; then
    return 0
  fi
  return 1
}

step::kubernetes.generate.kubeconfig.global::run() {
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

  local cluster_dir="${KUBEXM_ROOT}/packages/${cluster_name}"
  local first_master
  first_master=$(config::get_role_members 'control-plane' | awk '{print $1}')
  if [[ -z "${first_master}" ]]; then
    log::error "No control-plane node found for kubeconfig"
    return 1
  fi
  local admin_conf="${cluster_dir}/${first_master}/kubeconfig/admin.conf"
  if [[ -f "${admin_conf}" ]]; then
    mkdir -p "${cluster_dir}/kubeconfig"
    cp "${admin_conf}" "${cluster_dir}/kubeconfig/admin.conf"
    export KUBECONFIG="${cluster_dir}/kubeconfig/admin.conf"
  else
    log::error "admin.conf not found for ${first_master}: ${admin_conf}"
    return 1
  fi
}

step::kubernetes.generate.kubeconfig.global::rollback() { return 0; }

step::kubernetes.generate.kubeconfig.global::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
