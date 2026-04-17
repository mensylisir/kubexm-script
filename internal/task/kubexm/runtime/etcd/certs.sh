#!/usr/bin/env bash
set -euo pipefail

step::cluster.node.certs.etcd::check() { return 1; }

step::cluster.node.certs.etcd::run() {
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

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/node_certs.sh"
  node_certs::prepare "${cluster_name}"

  if [[ "${NC_ETCD_TYPE}" != "kubexm" ]]; then
    return 0
  fi

  local node_name
  node_name=$(node_certs::resolve_node_name)
  if [[ -z "${node_name}" ]]; then
    log::error "Failed to resolve node name for ${KUBEXM_HOST}"
    return 1
  fi
  if ! echo " ${NC_ETCD_NODES} " | grep -qw " ${node_name} "; then
    return 0
  fi
  if echo " ${NC_CONTROL_PLANE_NODES} " | grep -qw " ${node_name} "; then
    return 0
  fi

  local node_ip
  node_ip=$(config::get_host_param "${node_name}" "address")
  local node_cert_dir="${NC_CLUSTER_DIR}/${node_name}/certs"
  log::info "Generating etcd certificates for: ${node_name}"

  mkdir -p "${node_cert_dir}/etcd"
  cp "${NC_SHARED_CA_DIR}/etcd/ca.crt" "${node_cert_dir}/etcd/"
  cp "${NC_SHARED_CA_DIR}/etcd/ca.key" "${node_cert_dir}/etcd/"

  pki::etcd::generate_all "${node_cert_dir}/etcd" "${NC_SHARED_CA_DIR}/kubernetes" "${node_ip}"
}

step::cluster.node.certs.etcd::rollback() { return 0; }

step::cluster.node.certs.etcd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
