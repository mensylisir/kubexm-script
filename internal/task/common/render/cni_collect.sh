#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.cni.collect::check() { return 1; }

step::cluster.render.cni.collect::run() {
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

  local mode registry_host registry_port registry_addr registry_endpoint_scheme
  mode=$(config::get_mode)
  registry_host=$(config::get_registry_host)
  registry_port=$(config::get_registry_port)
  registry_addr="${registry_host}:${registry_port}"
  registry_endpoint_scheme="http"

  if [[ -z "${registry_host}" ]]; then
    if [[ "${mode}" == "offline" ]]; then
      log::error "Registry host is required in offline mode"
      return 1
    fi
    registry_addr="registry.k8s.io"
    registry_endpoint_scheme="https"
    log::warn "Registry host is empty, using public registry defaults in online mode"
  fi

  local k8s_version network_plugin first_master pod_cidr
  k8s_version=$(config::get_kubernetes_version)
  network_plugin=$(config::get_network_plugin)
  pod_cidr=$(config::get_pod_cidr)
  first_master=$(config::get_role_members 'control-plane' | awk '{print $1}')

  if [[ -z "${first_master}" ]]; then
    log::warn "No control-plane nodes found, skipping CNI rendering"
    context::set "cni_skip" "true"
    return 0
  fi

  context::set "cni_skip" "false"
  context::set "cni_registry_addr" "${registry_addr}"
  context::set "cni_registry_scheme" "${registry_endpoint_scheme}"
  context::set "cni_k8s_version" "${k8s_version}"
  context::set "cni_network_plugin" "${network_plugin}"
  context::set "cni_pod_cidr" "${pod_cidr}"
  context::set "cni_first_master" "${first_master}"
  context::set "cni_first_master_dir" "${KUBEXM_ROOT}/packages/${cluster_name}/${first_master}"
  context::set "cni_packages_dir" "${KUBEXM_ROOT}/packages"
}

step::cluster.render.cni.collect::rollback() { return 0; }

step::cluster.render.cni.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
