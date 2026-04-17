#!/usr/bin/env bash
set -euo pipefail

step::cluster.node.certs.control.plane.etcd::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "node_certs_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip cert generation
  fi
  return 1  # need to generate certs
}

step::cluster.node.certs.control.plane.etcd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local skip
  skip="$(context::get "node_certs_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0
  fi

  local etcd_type shared_ca_dir node_name node_cert_dir cluster_dir
  etcd_type="$(context::get "node_certs_cp_etcd_type" || true)"
  shared_ca_dir="$(context::get "node_certs_cp_shared_ca_dir" || true)"
  node_name="$(context::get "node_certs_cp_name" || true)"
  node_cert_dir="$(context::get "node_certs_cp_cert_dir" || true)"
  cluster_dir="$(context::get "node_certs_cp_cluster_dir" || true)"

  mkdir -p "${cluster_dir}/${node_name}/certs/etcd"
  if [[ "${etcd_type}" == "kubexm" && -d "${shared_ca_dir}/etcd" ]]; then
    cp "${shared_ca_dir}/etcd/ca.crt" "${cluster_dir}/${node_name}/certs/etcd/"
    cp "${shared_ca_dir}/etcd/healthcheck-client.crt" "${cluster_dir}/${node_name}/certs/etcd/"
    cp "${shared_ca_dir}/etcd/healthcheck-client.key" "${cluster_dir}/${node_name}/certs/etcd/"
    if [[ -f "${shared_ca_dir}/etcd/apiserver-etcd-client.crt" ]]; then
      cp "${shared_ca_dir}/etcd/apiserver-etcd-client.crt" "${node_cert_dir}/"
    fi
    if [[ -f "${shared_ca_dir}/etcd/apiserver-etcd-client.key" ]]; then
      cp "${shared_ca_dir}/etcd/apiserver-etcd-client.key" "${node_cert_dir}/"
    elif [[ -f "${shared_ca_dir}/etcd/apiserver-etcd-client-key.pem" ]]; then
      cp "${shared_ca_dir}/etcd/apiserver-etcd-client-key.pem" "${node_cert_dir}/apiserver-etcd-client.key"
    fi
  fi
}

step::cluster.node.certs.control.plane.etcd::rollback() { return 0; }

step::cluster.node.certs.control.plane.etcd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role_excluding_first "control-plane"
}
