#!/usr/bin/env bash
set -euo pipefail

step::certs.rotate.pull.old::check() { return 1; }

step::certs.rotate.pull.old::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local cluster_name cert_type deploy_type
  cluster_name="$(context::get "cert_rotate_cluster" || echo "${KUBEXM_CLUSTER_NAME:-}")"
  cert_type="$(context::get "cert_rotate_type" || echo "$(defaults::get_cert_type)")"
  deploy_type="$(context::get "cert_rotate_deploy_type" || echo "$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)")"

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

  local base_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${node_name}/old"

  log::info "Pulling old certificates from ${node_name} (${KUBEXM_HOST})..."

  mkdir -p "${base_dir}/kubernetes/pki" "${base_dir}/kubernetes/kubeconfig"

  if [[ "${cert_type}" == "kubernetes" || "${cert_type}" == "all" ]]; then
    log::info "  Pulling Kubernetes certificates..."
    runner::remote_copy_from "/etc/kubernetes/pki/*.crt" "${base_dir}/kubernetes/pki/" || true
    runner::remote_copy_from "/etc/kubernetes/pki/*.key" "${base_dir}/kubernetes/pki/" || true
    runner::remote_copy_from "/etc/kubernetes/pki/*.pub" "${base_dir}/kubernetes/pki/" || true
    runner::remote_copy_from "/etc/kubernetes/pki/front-proxy-*" "${base_dir}/kubernetes/pki/" || true
    runner::remote_copy_from "/etc/kubernetes/*.conf" "${base_dir}/kubernetes/kubeconfig/" || true
    if [[ "${deploy_type}" == "kubeadm" ]]; then
      mkdir -p "${base_dir}/manifests"
      runner::remote_copy_from "/etc/kubernetes/manifests/*.yaml" "${base_dir}/manifests/" || true
    fi
  fi

  if [[ "${cert_type}" == "etcd" || "${cert_type}" == "all" ]]; then
    log::info "  Pulling etcd certificates..."
    mkdir -p "${base_dir}/etcd"
    if [[ "${deploy_type}" == "kubeadm" ]]; then
      runner::remote_copy_from "/etc/kubernetes/pki/etcd/*.crt" "${base_dir}/etcd/" || true
      runner::remote_copy_from "/etc/kubernetes/pki/etcd/*.key" "${base_dir}/etcd/" || true
    else
      runner::remote_copy_from "/etc/etcd/ssl/*.crt" "${base_dir}/etcd/" || true
      runner::remote_copy_from "/etc/etcd/ssl/*.key" "${base_dir}/etcd/" || true
    fi
  fi

  log::success "Old certificates saved to: ${base_dir}"
}

step::certs.rotate.pull.old::rollback() { return 0; }

step::certs.rotate.pull.old::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local out="" node node_ip
  for node in $(config::get_all_host_names); do
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}
