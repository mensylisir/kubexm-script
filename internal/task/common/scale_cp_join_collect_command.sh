#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cp.join.collect.command::check() { return 1; }

step::cluster.scale.cp.join.collect.command::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  local cluster_name join_token ca_hash cert_key first_master_ip
  cluster_name="${KUBEXM_CLUSTER_NAME:-}"

  # Try to load from join.env first (set by kubeadm.prepare_join during cluster create)
  local join_file="${KUBEXM_ROOT}/packages/${cluster_name}/kubeadm/join.env"
  if [[ -f "${join_file}" ]]; then
    # shellcheck disable=SC1090
    source "${join_file}"
    join_token="${JOIN_TOKEN:-}"
    ca_hash="${CA_HASH:-}"
    cert_key="${CERT_KEY:-}"
    first_master_ip="${FIRST_MASTER_IP:-}"
  fi

  # If join.env not available or missing values, generate fresh ones
  if [[ -z "${join_token}" || -z "${ca_hash}" || -z "${cert_key}" ]]; then
    log::info "Generating fresh kubeadm join parameters for control-plane..."

    # Get first master IP from config
    local masters first first_master_ip
    masters=$(config::get_role_members 'control-plane')
    first=$(echo "${masters}" | awk '{print $1}')
    first_master_ip=$(config::get_host_param "${first}" "address")

    if [[ -z "${first_master_ip}" ]]; then
      log::error "Cannot determine first master IP"
      return 1
    fi

    # Generate fresh token using kubectl on the bastion/local machine
    local token_output
    token_output=$(kubeadm token create --print-join-command 2>/dev/null || true)
    if [[ -z "${token_output}" ]]; then
      log::error "Failed to create kubeadm token"
      return 1
    fi

    # Extract token and ca-hash from the output
    # Output format: "kubeadm join <host>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    join_token=$(echo "${token_output}" | sed -n 's/.*--token \([^ ]*\).*/\1/p')
    ca_hash=$(echo "${token_output}" | sed -n 's/.*--discovery-token-ca-cert-hash \([^ ]*\).*/\1/p')

    # Get certificate key by SSHing to first master
    local saved_host="${KUBEXM_HOST:-}"
    KUBEXM_HOST="${first_master_ip}"
    cert_key=$(runner::remote_exec "kubeadm init phase upload-certs --upload-certs 2>/dev/null" | tail -1 || true)
    KUBEXM_HOST="${saved_host}"

    if [[ -z "${cert_key}" ]]; then
      log::error "Failed to get certificate key from first master"
      return 1
    fi

    log::info "Fresh join parameters generated successfully"
  fi

  local node_name
  node_name="$(context::get "cluster_scale_cp_node" || true)"
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  local join_command="kubeadm join ${first_master_ip}:6443 --token ${join_token} --discovery-token-ca-cert-hash ${ca_hash} --control-plane --certificate-key ${cert_key} --node-name ${node_name}"

  context::set "cluster_scale_cp_cmd" "${join_command}"
  context::set "cluster_scale_cp_first_master_ip" "${first_master_ip}"
}

step::cluster.scale.cp.join.collect.command::rollback() { return 0; }

step::cluster.scale.cp.join.collect.command::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}