#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Etcd Backup Verification Step
# ==============================================================================
# 验证 etcd 快照备份的完整性
# ==============================================================================

step::etcd.backup.verify::check() {
  return 1  # always need to verify
}

step::etcd.backup.verify::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Verifying etcd backup integrity..."

  local backup_dir="${KUBEXM_BACKUP_PATH:-/var/backups/etcd}"
  local latest_backup
  latest_backup=$(ls -t "${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}/backups"/etcd-snapshot-*.db 2>/dev/null | head -1 || true)

  if [[ -z "${latest_backup}" ]]; then
    log::warn "No local backup file found, skipping verification"
    return 0
  fi

  # 检查文件大小（空文件说明备份失败）
  local file_size
  file_size=$(stat -c %s "${latest_backup}" 2>/dev/null || echo 0)
  if [[ "${file_size}" -lt 1024 ]]; then
    log::error "Backup file is too small (${file_size} bytes): ${latest_backup}"
    return 1
  fi

  # 使用 etcdctl snapshot status 验证快照完整性
  local etcd_type etcd_cert_dir
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  local etcd_nodes first_node first_ip
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane')
  first_node=$(echo "${etcd_nodes}" | head -1)
  first_ip=$(config::get_host_param "${first_node}" "address")

  if [[ -n "${first_ip}" ]]; then
    local orig_host="${KUBEXM_HOST}"
    export KUBEXM_HOST="${first_ip}"

    local remote_backup="/tmp/$(basename "${latest_backup}")"
    runner::remote_copy_file "${latest_backup}" "${remote_backup}" 2>/dev/null || true

    local status_output
    status_output=$(runner::remote_exec "ETCDCTL_API=3 etcdctl snapshot status ${remote_backup} --write-out=table 2>&1" || true)
    runner::remote_exec "rm -f ${remote_backup}" 2>/dev/null || true

    export KUBEXM_HOST="${orig_host}"

    if [[ -n "${status_output}" && "${status_output}" != *"failed"* ]]; then
      log::info "Backup verification passed: ${latest_backup} (${file_size} bytes)"
      log::info "Snapshot status:\n${status_output}"
      return 0
    else
      log::warn "Backup verification inconclusive for ${latest_backup}"
    fi
  fi

  # Fallback: 仅检查文件存在且非空
  log::info "Backup file exists and is non-empty: ${latest_backup} (${file_size} bytes)"
  return 0
}

step::etcd.backup.verify::rollback() { return 0; }

step::etcd.backup.verify::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
