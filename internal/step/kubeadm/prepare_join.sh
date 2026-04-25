#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.prepare.join::check() {
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local join_dir="${KUBEXM_ROOT}/packages/${cluster_name}/kubeadm"
  local join_file="${join_dir}/join.env"
  if [[ -f "${join_file}" ]]; then
    return 0
  fi
  return 1
}

step::kubeadm.prepare.join::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*) cluster_name="${arg#*=}" ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local first_master
  first_master=$(config::get_role_members 'control-plane' | awk '{print $1}')
  if [[ -z "${first_master}" ]]; then
    log::error "No control-plane node found"
    return 1
  fi
  local first_master_ip
  first_master_ip=$(config::get_host_param "${first_master}" "address")
  if [[ -z "${first_master_ip}" ]]; then
    log::error "Failed to resolve first master IP"
    return 1
  fi

  local target_host="${KUBEXM_HOST}"
  KUBEXM_HOST="${first_master_ip}"
  local join_token ca_hash cert_key
  join_token=$(runner::remote_exec "kubeadm token create --ttl 24h --config /etc/kubernetes/kubeadm-config.yaml") || { KUBEXM_HOST="${target_host}"; log::error "Failed to create kubeadm token"; return 1; }
  ca_hash=$(runner::remote_exec "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'") || { KUBEXM_HOST="${target_host}"; log::error "Failed to extract CA hash"; return 1; }
  cert_key=$(runner::remote_exec "kubeadm init phase upload-certs --upload-certs --config /etc/kubernetes/kubeadm-config.yaml 2>/dev/null | grep -A 1 'certificate key' | tail -n 1 | xargs") || { KUBEXM_HOST="${target_host}"; log::error "Failed to upload certs"; return 1; }
  KUBEXM_HOST="${target_host}"

  if [[ -z "${join_token}" || -z "${ca_hash}" || -z "${cert_key}" ]]; then
    log::error "Failed to generate join parameters from first master"
    return 1
  fi

  local join_dir="${KUBEXM_ROOT}/packages/${cluster_name}/kubeadm"
  mkdir -p "${join_dir}" || { log::error "Failed to create join directory: ${join_dir}"; return 1; }
  local join_file="${join_dir}/join.env"
  cat > "${join_file}" <<EOF
JOIN_TOKEN="${join_token}"
CA_HASH="${ca_hash}"
CERT_KEY="${cert_key}"
FIRST_MASTER_IP="${first_master_ip}"
EOF
  log::info "Saved kubeadm join parameters to ${join_file}"
}

step::kubeadm.prepare.join::rollback() { return 0; }

step::kubeadm.prepare.join::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
