#!/usr/bin/env bash
set -euo pipefail

step::etcd.backup.copy::check() {
  return 1  # always need to copy backup
}

step::etcd.backup.copy::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Creating etcd backup snapshot..."

  local etcd_type backup_dir etcd_cert_dir snapshot_path
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  # 支持通过 KUBEXM_BACKUP_PATH 覆盖默认备份目录
  backup_dir="${KUBEXM_BACKUP_PATH:-/var/backups/etcd}"
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  snapshot_path="${backup_dir}/etcd-snapshot-${timestamp}.db"

  local backup_cmd="mkdir -p ${backup_dir} && ETCDCTL_API=3 etcdctl snapshot save ${snapshot_path} --endpoints=https://127.0.0.1:2379 --cacert=${etcd_cert_dir}/ca.crt --cert=${etcd_cert_dir}/server.crt --key=${etcd_cert_dir}/server.key"
  runner::remote_exec "${backup_cmd}" || { log::error "etcdctl snapshot save failed on ${KUBEXM_HOST}"; return 1; }

  # Copy snapshot to local
  local local_backup_dir
  local_backup_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}/backups"
  mkdir -p "${local_backup_dir}" || { log::error "Failed to create local backup directory: ${local_backup_dir}"; return 1; }
  runner::remote_copy_from "${snapshot_path}" "${local_backup_dir}/etcd-snapshot-${timestamp}.db"

  log::info "Etcd backup saved to ${local_backup_dir}/etcd-snapshot-${timestamp}.db"
}

step::etcd.backup.copy::rollback() { return 0; }

step::etcd.backup.copy::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local etcd_nodes
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane')
  local first_node
  first_node=$(echo "${etcd_nodes}" | head -1)
  if [[ -z "${first_node}" ]]; then
    return 0
  fi
  local first_ip
  first_ip=$(config::get_host_param "${first_node}" "address")
  [[ -n "${first_ip}" ]] && echo "${first_ip}"
}