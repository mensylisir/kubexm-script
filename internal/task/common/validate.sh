#!/usr/bin/env bash
set -euo pipefail

step::cluster.validate::check() { return 1; }

step::cluster.validate::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for cluster validation" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/domain/domain.sh"

  if ! config::validate; then
    log::error "Config validation failed"
    return 1
  fi
  if ! config::validate_consistency; then
    log::error "Config consistency validation failed"
    return 1
  fi

  local k8s_type etcd_type lb_enabled lb_mode lb_type master_nodes masters_count
  k8s_type=$(config::get_kubernetes_type)
  etcd_type=$(config::get_etcd_type)
  lb_enabled=$(config::get_loadbalancer_enabled)
  lb_mode=$(config::get_loadbalancer_mode)
  lb_type=$(config::get_loadbalancer_type)
  master_nodes=$(config::get_role_members 'control-plane')
  masters_count=0
  local node
  for node in ${master_nodes}; do
    [[ -n "${node}" ]] && ((++masters_count))
  done

  if ! domain::validate_cluster_combination "${k8s_type}" "${etcd_type}" "${masters_count}" "${lb_enabled}" "${lb_mode}" "${lb_type}"; then
    log::error "Invalid cluster combination: k8s=${k8s_type}, etcd=${etcd_type}, masters=${masters_count}, lb_enabled=${lb_enabled}, lb_mode=${lb_mode}, lb_type=${lb_type}"
    return 1
  fi

  local mode
  mode=$(config::get_mode)
  if [[ "${mode}" == "offline" ]]; then
    if [[ ! -d "${KUBEXM_ROOT}/packages" ]]; then
      log::error "Packages directory not found: ${KUBEXM_ROOT}/packages"
      log::error "Please run 'kubexm download --cluster=${cluster_name}' on a connected machine first"
      return 1
    fi
  fi
}

step::cluster.validate::rollback() { return 0; }

step::cluster.validate::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}

# Task wrapper for pipeline usage
task::cluster::validate() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.validate:${KUBEXM_ROOT}/internal/task/common/validate.sh"
}

export -f task::cluster::validate
