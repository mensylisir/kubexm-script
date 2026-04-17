#!/usr/bin/env bash
set -euo pipefail

step::etcd.restore.copy::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/var/lib/etcd/member"; then
    return 0
  fi
  return 1
}

step::etcd.restore.copy::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local snapshot_path backup_dir
  # 优先使用 pipeline 传递的 KUBEXM_RESTORE_PATH
  snapshot_path="${KUBEXM_RESTORE_PATH:-}"
  if [[ -z "${snapshot_path}" ]]; then
    snapshot_path="$(context::get "etcd_snapshot_path" || true)"
  fi
  if [[ -z "${snapshot_path}" ]]; then
    # Try to find latest backup
    backup_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}/backups"
    snapshot_path=$(ls -t "${backup_dir}"/etcd-snapshot-*.db 2>/dev/null | head -1 || true)
  fi

  if [[ -z "${snapshot_path}" || ! -f "${snapshot_path}" ]]; then
    log::error "No etcd snapshot found for restore"
    return 1
  fi

  # ============================================================================
  # Check if backup is encrypted and decrypt if needed
  # ============================================================================
  local working_snapshot="${snapshot_path}"
  local needs_cleanup="false"
  
  if [[ "${snapshot_path}" == *.enc ]]; then
    log::info "Detected encrypted backup: ${snapshot_path}"
    
    # Check for encryption key
    if [[ -z "${KUBEXM_BACKUP_ENCRYPTION_KEY:-}" ]]; then
      log::error "Backup is encrypted but KUBEXM_BACKUP_ENCRYPTION_KEY is not set"
      log::error "Please provide the encryption key used during backup"
      return 1
    fi
    
    # Decrypt the backup
    if command -v openssl &>/dev/null; then
      local decrypted_path="${snapshot_path%.enc}.decrypted"
      log::info "Decrypting backup..."
      
      openssl enc -aes-256-cbc \
        -d \
        -pbkdf2 \
        -in "${snapshot_path}" \
        -out "${decrypted_path}" \
        -pass pass:"${KUBEXM_BACKUP_ENCRYPTION_KEY}" || {
        log::error "Decryption failed! Wrong encryption key?"
        return 1
      }
      
      working_snapshot="${decrypted_path}"
      needs_cleanup="true"
      log::info "✓ Backup decrypted"
    else
      log::error "openssl not found, cannot decrypt backup"
      return 1
    fi
  fi

  log::info "Restoring etcd from snapshot ${working_snapshot}..."

  local remote_snapshot_path="/tmp/$(basename "${working_snapshot}")"
  runner::remote_copy_file "${working_snapshot}" "${remote_snapshot_path}" || { log::error "Failed to copy snapshot to ${KUBEXM_HOST}"; return 1; }

  # Cleanup decrypted file after upload
  if [[ "${needs_cleanup}" == "true" ]]; then
    rm -f "${working_snapshot}"
  fi

  local etcd_type etcd_cert_dir
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  # Clear existing data dir
  runner::remote_exec "rm -rf /var/lib/etcd/*" || { log::error "Failed to clear etcd data dir on ${KUBEXM_HOST}"; return 1; }

  # Restore snapshot
  local restore_cmd="ETCDCTL_API=3 etcdctl snapshot restore ${remote_snapshot_path} --endpoints=https://127.0.0.1:2379 --cacert=${etcd_cert_dir}/ca.crt --cert=${etcd_cert_dir}/server.crt --key=${etcd_cert_dir}/server.key --data-dir=/var/lib/etcd"
  runner::remote_exec "${restore_cmd}" || { log::error "etcdctl snapshot restore failed on ${KUBEXM_HOST}"; return 1; }
  runner::remote_exec "rm -f ${remote_snapshot_path}" >/dev/null 2>&1 || true

  log::info "Etcd snapshot restored on ${KUBEXM_HOST}"
}

step::etcd.restore.copy::rollback() { return 0; }

step::etcd.restore.copy::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}