#!/usr/bin/env bash
set -euo pipefail

step::cluster.node.certs.control.plane.generate::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "node_certs_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip cert generation
  fi
  return 1  # need to generate certs
}

step::cluster.node.certs.control.plane.generate::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/utils/pki.sh"

  local skip
  skip="$(context::get "node_certs_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0
  fi

  local node_name node_ip node_sans node_cert_dir cluster_domain shared_ca_dir
  node_name="$(context::get "node_certs_cp_name" || true)"
  node_ip="$(context::get "node_certs_cp_ip" || true)"
  node_sans="$(context::get "node_certs_cp_sans" || true)"
  node_cert_dir="$(context::get "node_certs_cp_cert_dir" || true)"
  cluster_domain="$(context::get "node_certs_cp_cluster_domain" || true)"
  shared_ca_dir="$(context::get "node_certs_cp_shared_ca_dir" || true)"

  log::info "Generating certificates for control-plane: ${node_name}"
  mkdir -p "${node_cert_dir}"
  cp "${shared_ca_dir}/kubernetes/ca.crt" "${node_cert_dir}/"
  cp "${shared_ca_dir}/kubernetes/ca.key" "${node_cert_dir}/"
  if [[ -f "${shared_ca_dir}/kubernetes/ca-key.pem" ]]; then
    cp "${shared_ca_dir}/kubernetes/ca-key.pem" "${node_cert_dir}/"
  fi
  cp "${shared_ca_dir}/kubernetes/front-proxy-ca.crt" "${node_cert_dir}/"
  if [[ -f "${shared_ca_dir}/kubernetes/front-proxy-ca.key" ]]; then
    cp "${shared_ca_dir}/kubernetes/front-proxy-ca.key" "${node_cert_dir}/"
  fi
  if [[ -f "${shared_ca_dir}/kubernetes/front-proxy-ca-key.pem" ]]; then
    cp "${shared_ca_dir}/kubernetes/front-proxy-ca-key.pem" "${node_cert_dir}/"
  fi
  cp "${shared_ca_dir}/kubernetes/sa.pub" "${node_cert_dir}/"
  cp "${shared_ca_dir}/kubernetes/sa.key" "${node_cert_dir}/"

  pki::apiserver::generate_all "${node_cert_dir}" "${cluster_domain}" "${node_sans}"
  pki::front_proxy::generate_all "${node_cert_dir}"
  pki::generate_kubernetes_clients "${node_cert_dir}" "${node_name}" "${node_ip}"
}

step::cluster.node.certs.control.plane.generate::rollback() { return 0; }

step::cluster.node.certs.control.plane.generate::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role_excluding_first "control-plane"
}
