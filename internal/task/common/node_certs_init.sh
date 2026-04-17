#!/usr/bin/env bash
set -euo pipefail

step::cluster.node.certs.init::check() { return 1; }

step::cluster.node.certs.init::run() {
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

  if [[ -z "${NC_FIRST_MASTER}" ]]; then
    log::error "No control-plane node found"
    return 1
  fi

  local first_master_ip
  first_master_ip=$(config::get_host_param "${NC_FIRST_MASTER}" "address")
  local first_master_sans="${NC_FIRST_MASTER},${first_master_ip},${NC_API_VIP},${NC_K8S_SVC_IP},kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.${NC_CLUSTER_DOMAIN},localhost,127.0.0.1"
  log::info "Generating PKI for first master: ${NC_FIRST_MASTER} (SANs: ${first_master_sans})"

  pki::init_pki "${NC_SHARED_CA_DIR}/kubernetes" "${NC_CLUSTER_DOMAIN}" "${first_master_sans}" "${NC_ALL_ETCD_IPS}"
  pki::generate_kubernetes_clients "${NC_SHARED_CA_DIR}/kubernetes" "${NC_FIRST_MASTER}" "${first_master_ip}"
  if [[ "${NC_ETCD_TYPE}" == "kubexm" && -d "${NC_SHARED_CA_DIR}/kubernetes/etcd" ]]; then
    cp -r "${NC_SHARED_CA_DIR}/kubernetes/etcd" "${NC_SHARED_CA_DIR}/"
    if [[ -f "${NC_SHARED_CA_DIR}/etcd/apiserver-etcd-client.crt" ]]; then
      cp "${NC_SHARED_CA_DIR}/etcd/apiserver-etcd-client.crt" "${NC_SHARED_CA_DIR}/kubernetes/"
    fi
    if [[ -f "${NC_SHARED_CA_DIR}/etcd/apiserver-etcd-client.key" ]]; then
      cp "${NC_SHARED_CA_DIR}/etcd/apiserver-etcd-client.key" "${NC_SHARED_CA_DIR}/kubernetes/"
    elif [[ -f "${NC_SHARED_CA_DIR}/etcd/apiserver-etcd-client-key.pem" ]]; then
      cp "${NC_SHARED_CA_DIR}/etcd/apiserver-etcd-client-key.pem" "${NC_SHARED_CA_DIR}/kubernetes/apiserver-etcd-client.key"
    fi
  fi
}

step::cluster.node.certs.init::rollback() { return 0; }

step::cluster.node.certs.init::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
