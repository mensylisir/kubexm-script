#!/usr/bin/env bash
set -euo pipefail

step::cluster.node.certs.worker::check() { return 1; }

step::cluster.node.certs.worker::run() {
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

  local node_name
  node_name=$(node_certs::resolve_node_name)
  if [[ -z "${node_name}" ]]; then
    log::error "Failed to resolve node name for ${KUBEXM_HOST}"
    return 1
  fi
  if ! echo " $(config::get_role_members 'worker') " | grep -qw " ${node_name} "; then
    return 0
  fi

  local node_ip
  node_ip=$(config::get_host_param "${node_name}" "address")
  local node_cert_dir="${NC_CLUSTER_DIR}/${node_name}/certs/kubernetes"
  log::info "Generating certificates for worker: ${node_name}"

  mkdir -p "${node_cert_dir}"
  cp "${NC_SHARED_CA_DIR}/kubernetes/ca.crt" "${node_cert_dir}/"
  cp "${NC_SHARED_CA_DIR}/kubernetes/ca.key" "${node_cert_dir}/"
  if [[ -f "${NC_SHARED_CA_DIR}/kubernetes/ca-key.pem" ]]; then
    cp "${NC_SHARED_CA_DIR}/kubernetes/ca-key.pem" "${node_cert_dir}/"
  fi
  cp "${NC_SHARED_CA_DIR}/kubernetes/front-proxy-ca.crt" "${node_cert_dir}/"
  if [[ -f "${NC_SHARED_CA_DIR}/kubernetes/front-proxy-ca.key" ]]; then
    cp "${NC_SHARED_CA_DIR}/kubernetes/front-proxy-ca.key" "${node_cert_dir}/"
  fi
  if [[ -f "${NC_SHARED_CA_DIR}/kubernetes/front-proxy-ca-key.pem" ]]; then
    cp "${NC_SHARED_CA_DIR}/kubernetes/front-proxy-ca-key.pem" "${node_cert_dir}/"
  fi
  cp "${NC_SHARED_CA_DIR}/kubernetes/sa.pub" "${node_cert_dir}/"
  cp "${NC_SHARED_CA_DIR}/kubernetes/sa.key" "${node_cert_dir}/"

  pki::generate_node_clients "${node_cert_dir}" "${node_name}" "${node_ip}"
}

step::cluster.node.certs.worker::rollback() { return 0; }

step::cluster.node.certs.worker::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
