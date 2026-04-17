#!/usr/bin/env bash
set -euo pipefail

step::cluster.node.certs.control.plane.collect::check() { return 1; }

step::cluster.node.certs.control.plane.collect::run() {
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
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/node_certs.sh"
  node_certs::prepare "${cluster_name}"

  local node_name
  node_name=$(node_certs::resolve_node_name)
  if [[ -z "${node_name}" ]]; then
    log::error "Failed to resolve node name for ${KUBEXM_HOST}"
    return 1
  fi

  local skip="false"
  if [[ "${node_name}" == "${NC_FIRST_MASTER}" ]]; then
    skip="true"
  fi
  if ! echo " ${NC_CONTROL_PLANE_NODES} " | grep -qw " ${node_name} "; then
    skip="true"
  fi

  local node_ip
  node_ip=$(config::get_host_param "${node_name}" "address")
  local node_sans="${node_name},${node_ip},${NC_API_VIP},${NC_K8S_SVC_IP},kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.${NC_CLUSTER_DOMAIN},localhost,127.0.0.1"
  local node_cert_dir="${NC_CLUSTER_DIR}/${node_name}/certs/kubernetes"

  context::set "node_certs_cp_skip" "${skip}"
  context::set "node_certs_cp_name" "${node_name}"
  context::set "node_certs_cp_ip" "${node_ip}"
  context::set "node_certs_cp_sans" "${node_sans}"
  context::set "node_certs_cp_cert_dir" "${node_cert_dir}"
  context::set "node_certs_cp_cluster_domain" "${NC_CLUSTER_DOMAIN}"
  context::set "node_certs_cp_cluster_dir" "${NC_CLUSTER_DIR}"
  context::set "node_certs_cp_shared_ca_dir" "${NC_SHARED_CA_DIR}"
  context::set "node_certs_cp_etcd_type" "${NC_ETCD_TYPE}"
}

step::cluster.node.certs.control.plane.collect::rollback() { return 0; }

step::cluster.node.certs.control.plane.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role_excluding_first "control-plane"
}
