#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Etcd Restore Pre-Backup Step
# ==============================================================================
# 恢复前先备份当前 etcd 数据（防止恢复失败导致数据丢失）
# ==============================================================================

step::etcd.restore.prebackup::check() {
  return 1  # always need to backup before restore
}

step::etcd.restore.prebackup::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Creating pre-restore etcd backup..."

  local etcd_type etcd_cert_dir backup_dir
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  backup_dir="/var/backups/etcd"
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  local etcd_nodes first_node first_ip
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane')
  first_node=$(echo "${etcd_nodes}" | head -1)
  if [[ -z "${first_node}" ]]; then
    log::warn "No etcd nodes found, skipping pre-restore backup"
    return 0
  fi
  first_ip=$(config::get_host_param "${first_node}" "address")
  if [[ -z "${first_ip}" ]]; then
    log::warn "Cannot get IP for etcd node, skipping pre-restore backup"
    return 0
  fi

  local orig_host="${KUBEXM_HOST}"
  export KUBEXM_HOST="${first_ip}"

  local timestamp snapshot_path
  timestamp=$(date +%Y%m%d-%H%M%S)
  snapshot_path="${backup_dir}/etcd-snapshot-prerestore-${timestamp}.db"

  local backup_cmd="mkdir -p ${backup_dir} && ETCDCTL_API=3 etcdctl snapshot save ${snapshot_path} --endpoints=https://127.0.0.1:2379 --cacert=${etcd_cert_dir}/ca.crt --cert=${etcd_cert_dir}/server.crt --key=${etcd_cert_dir}/server.key"

  if runner::remote_exec "${backup_cmd}"; then
    # 复制到本地
    local local_backup_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}/backups"
    mkdir -p "${local_backup_dir}"
    runner::remote_copy_from "${snapshot_path}" "${local_backup_dir}/etcd-snapshot-prerestore-${timestamp}.db" || true
    log::info "Pre-restore backup created: ${snapshot_path}"
  else
    log::warn "Pre-restore backup failed, continuing with restore..."
  fi

  export KUBEXM_HOST="${orig_host}"
  return 0
}

step::etcd.restore.prebackup::rollback() { return 0; }

step::etcd.restore.prebackup::targets() {
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
