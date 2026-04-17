#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.pki.etcd.ca::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/pki/etcd/ca.crt"
}

step::kubernetes.distribute.pki.etcd.ca::run() {
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

  local etcd_type
  etcd_type=$(config::get_etcd_type)

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

  runner::remote_exec "mkdir -p /etc/kubernetes/pki/etcd" || true

  if [[ "${etcd_type}" == "kubexm" ]]; then
    # kubexm 独立 etcd：从 certs/etcd 目录分发 ca.crt
    local etcd_pki_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/certs/etcd"
    if [[ -f "${etcd_pki_dir}/ca.crt" ]]; then
      runner::remote_copy_file "${etcd_pki_dir}/ca.crt" "/etc/kubernetes/pki/etcd/ca.crt"
      log::info "ETCD CA distributed to ${KUBEXM_HOST}"
    fi
  elif [[ "${etcd_type}" == "exists" ]]; then
    # 外部 etcd：尝试从 packages/{cluster}/etcd/ 目录分发用户提供的 ca.crt
    local etcd_ca_dir="${KUBEXM_ROOT}/packages/${cluster_name}/etcd"
    if [[ -f "${etcd_ca_dir}/ca.crt" ]]; then
      runner::remote_copy_file "${etcd_ca_dir}/ca.crt" "/etc/kubernetes/pki/etcd/ca.crt"
      log::info "External ETCD CA distributed to ${KUBEXM_HOST}"
    else
      log::warn "External etcd ca.crt not found in ${etcd_ca_dir}/, ensure it exists for TLS connection"
    fi
    # 同样尝试分发 apiserver-etcd-client 证书（用户需预先提供）
    if [[ -f "${etcd_ca_dir}/apiserver-etcd-client.crt" && -f "${etcd_ca_dir}/apiserver-etcd-client.key" ]]; then
      runner::remote_copy_file "${etcd_ca_dir}/apiserver-etcd-client.crt" "/etc/kubernetes/pki/apiserver-etcd-client.crt"
      runner::remote_copy_file "${etcd_ca_dir}/apiserver-etcd-client.key" "/etc/kubernetes/pki/apiserver-etcd-client.key"
      runner::remote_exec "chmod 600 /etc/kubernetes/pki/apiserver-etcd-client.key"
      log::info "External ETCD client certs distributed to ${KUBEXM_HOST}"
    fi
  fi
  # etcd_type=kubeadm 时不需要分发，kubeadm init 会自动生成
}

step::kubernetes.distribute.pki.etcd.ca::rollback() { return 0; }

step::kubernetes.distribute.pki.etcd.ca::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
