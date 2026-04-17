#!/usr/bin/env bash
set -euo pipefail

step::cluster.config.dirs.collect::check() { return 1; }

step::cluster.config.dirs.collect::run() {
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
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local cluster_dir
  cluster_dir="${KUBEXM_ROOT}/packages/${cluster_name}"

  local control_plane_nodes worker_nodes etcd_nodes all_nodes
  control_plane_nodes=$(config::get_role_members 'control-plane')
  worker_nodes=$(config::get_role_members 'worker')
  etcd_nodes=$(config::get_role_members 'etcd')
  all_nodes="${control_plane_nodes} ${worker_nodes} ${etcd_nodes}"
  all_nodes=$(echo "${all_nodes}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

  local first_master
  first_master=$(echo "${control_plane_nodes}" | awk '{print $1}')

  local runtime_type network_plugin k8s_version metrics_enabled ingress_enabled ingress_type
  runtime_type=$(config::get_runtime_type)
  network_plugin=$(config::get_network_plugin)
  k8s_version=$(config::get_kubernetes_version)
  metrics_enabled=$(config::get_metrics_server_enabled)
  ingress_enabled=$(config::get_ingress_enabled)
  ingress_type=$(config::get_ingress_type)

  context::set "config_dirs_cluster_dir" "${cluster_dir}"
  context::set "config_dirs_all_nodes" "${all_nodes}"
  context::set "config_dirs_first_master" "${first_master}"
  context::set "config_dirs_runtime_type" "${runtime_type}"
  context::set "config_dirs_network_plugin" "${network_plugin}"
  context::set "config_dirs_k8s_version" "${k8s_version}"
  context::set "config_dirs_metrics_enabled" "${metrics_enabled}"
  context::set "config_dirs_ingress_enabled" "${ingress_enabled}"
  context::set "config_dirs_ingress_type" "${ingress_type}"
}

step::cluster.config.dirs.collect::rollback() { return 0; }

step::cluster.config.dirs.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
