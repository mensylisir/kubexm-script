#!/usr/bin/env bash
set -euo pipefail

step::etcd.backup.collect::check() {
  return 1  # always need to collect backup info
}

step::etcd.backup.collect::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Collecting etcd backup information..."

  local etcd_type etcd_cert_dir backup_dir
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  # 支持通过 KUBEXM_BACKUP_PATH 覆盖默认备份目录
  backup_dir="${KUBEXM_BACKUP_PATH:-/var/backups/etcd}"
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  # Store backup info in context
  context::set "etcd_backup_dir" "${backup_dir}"
  context::set "etcd_cert_dir" "${etcd_cert_dir}"

  log::info "Etcd backup info collected"
}

step::etcd.backup.collect::rollback() { return 0; }

step::etcd.backup.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local etcd_nodes _etcd_result
  _etcd_result=$(config::get_role_members 'etcd' 2>/dev/null || true)
  if [[ -z "${_etcd_result}" ]]; then
    etcd_nodes=$(config::get_role_members 'control-plane')
  else
    etcd_nodes="${_etcd_result}"
  fi
  local first_node
  first_node=$(echo "${etcd_nodes}" | head -1)
  if [[ -z "${first_node}" ]]; then
    return 0
  fi
  local first_ip
  first_ip=$(config::get_host_param "${first_node}" "address")
  [[ -n "${first_ip}" ]] && echo "${first_ip}"
}