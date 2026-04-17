#!/usr/bin/env bash
set -euo pipefail

step::certs.rotate.collect::check() { return 1; }

step::certs.rotate.collect::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local cert_type="${KUBEXM_CERT_ROTATE_TYPE:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --cert-type=*)
        cert_type="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for renew certs" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  if [[ -z "${cert_type}" ]]; then
    cert_type="$(defaults::get_cert_type)"
  fi

  local deploy_type
  deploy_type=$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)

  local api_server
  api_server=$(config::get_apiserver_address 2>/dev/null || echo "")
  if [[ -z "${api_server}" ]]; then
    api_server=$(config::get_loadbalancer_vip 2>/dev/null || echo "")
  fi
  if [[ -n "${api_server}" ]] && [[ ! "${api_server}" =~ ^https:// ]]; then
    api_server="https://${api_server}:6443"
  fi

  local cluster_domain
  cluster_domain=$(config::get_cluster_domain)

  local master_nodes worker_nodes etcd_nodes
  master_nodes=$(config::get_role_members "control-plane")
  if [[ -z "${master_nodes}" ]]; then
    master_nodes=$(config::get_role_members "master")
  fi
  worker_nodes=$(config::get_role_members "worker")
  etcd_nodes=$(config::get_role_members "etcd")

  local first_master
  first_master=$(echo "${master_nodes}" | awk '{print $1}')

  context::set "cert_rotate_cluster" "${cluster_name}"
  context::set "cert_rotate_type" "${cert_type}"
  context::set "cert_rotate_deploy_type" "${deploy_type}"
  context::set "cert_rotate_api_server" "${api_server}"
  context::set "cert_rotate_cluster_domain" "${cluster_domain}"
  context::set "cert_rotate_master_nodes" "${master_nodes}"
  context::set "cert_rotate_worker_nodes" "${worker_nodes}"
  context::set "cert_rotate_etcd_nodes" "${etcd_nodes}"
  context::set "cert_rotate_first_master" "${first_master}"
  context::set "cert_rotate_kubeconfig" "${KUBECONFIG:-/etc/kubernetes/admin.conf}"

  log::info "Cert rotation context collected: type=${cert_type} deploy=${deploy_type}"
}

step::certs.rotate.collect::rollback() { return 0; }

step::certs.rotate.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
