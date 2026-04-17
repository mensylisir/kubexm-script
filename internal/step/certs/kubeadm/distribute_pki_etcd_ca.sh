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
  if [[ "${etcd_type}" != "kubexm" ]]; then
    return 0
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

  local etcd_pki_dir
  etcd_pki_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/certs/etcd"
  if [[ ! -d "${etcd_pki_dir}" ]]; then
    return 0
  fi

  runner::remote_exec "mkdir -p /etc/kubernetes/pki/etcd"
  if [[ -f "${etcd_pki_dir}/ca.crt" ]]; then
    runner::remote_copy_file "${etcd_pki_dir}/ca.crt" "/etc/kubernetes/pki/etcd/ca.crt"
  fi
}

step::kubernetes.distribute.pki.etcd.ca::rollback() { return 0; }

step::kubernetes.distribute.pki.etcd.ca::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
