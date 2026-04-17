#!/usr/bin/env bash
set -euo pipefail

step::certs.rotate.generate.new::check() { return 1; }

step::certs.rotate.generate.new::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/cert-rotation.sh"

  local cluster_name cert_type api_server cluster_domain
  cluster_name="$(context::get "cert_rotate_cluster" || echo "${KUBEXM_CLUSTER_NAME:-}")"
  cert_type="$(context::get "cert_rotate_type" || echo "$(defaults::get_cert_type)")"
  api_server="$(context::get "cert_rotate_api_server" || echo "")"
  cluster_domain="$(context::get "cert_rotate_cluster_domain" || echo "$(config::get_cluster_domain)")"

  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for renew certs" >&2
    return 2
  fi

  local node_name=""
  local node
  for node in $(config::get_all_host_names); do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  if [[ -z "${node_name}" ]]; then
    node_name="${KUBEXM_HOST}"
  fi

  rotation::generate_new_certs "${cluster_name}" "${node_name}" "${cert_type}" "${api_server}" "${cluster_domain}"
}

step::certs.rotate.generate.new::rollback() { return 0; }

step::certs.rotate.generate.new::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local out="" node node_ip
  for node in $(config::get_all_host_names); do
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}
