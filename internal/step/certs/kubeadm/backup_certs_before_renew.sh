#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: certs.backup.before.renew
# Backup certificates before renewal (safety measure)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/logger/log.sh"
source "${KUBEXM_ROOT}/internal/config/config.sh"
source "${KUBEXM_ROOT}/internal/runner/runner.sh"

BACKUP_DIR="/var/backups/kubexm-certs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

step::certs.backup.before.renew::check() {
  # Always backup before renewal
  return 1
}

step::certs.backup.before.renew::run() {
  local ctx="$1"
  shift

  log::info "Creating certificate backup before renewal..."

  local node_name="${KUBEXM_HOST_NAME:-unknown}"
  local cert_type="${CERT_BACKUP_TYPE:-all}"  # all, kubernetes, etcd

  local backup_subdir="${BACKUP_DIR}/pre-renew-${TIMESTAMP}-${node_name}"
  local backup_cmd="mkdir -p ${backup_subdir}"

  case "${cert_type}" in
    kubernetes)
      _backup_kubernetes_certs "${backup_subdir}" || return $?
      ;;
    etcd)
      _backup_etcd_certs "${backup_subdir}" || return $?
      ;;
    all|*)
      _backup_kubernetes_certs "${backup_subdir}" || true
      _backup_etcd_certs "${backup_subdir}" || true
      ;;
  esac

  # Copy backup to local machine
  _copy_backup_locally "${backup_subdir}" || true

  log::info "Certificate backup completed: ${backup_subdir}"
  return 0
}

_backup_kubernetes_certs() {
  local backup_path="$1"
  local pki_dir="/etc/kubernetes/pki"

  log::info "Backing up Kubernetes PKI directory..."

  local backup_k8s_cmd="
    if [ -d '${pki_dir}' ]; then
      mkdir -p '${backup_path}/kubernetes'
      cp -a '${pki_dir}' '${backup_path}/kubernetes/pki-backup'
      echo 'Kubernetes PKI backed up successfully'
    else
      echo 'Warning: Kubernetes PKI directory not found'
      exit 1
    fi
  "

  if runner::remote_exec "${backup_k8s_cmd}"; then
    log::info "✓ Kubernetes certificates backed up"
    return 0
  else
    log::error "Failed to backup Kubernetes certificates"
    return 1
  fi
}

_backup_etcd_certs() {
  local backup_path="$1"
  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)

  local etcd_cert_dir
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  log::info "Backing up etcd certificates from ${etcd_cert_dir}..."

  local backup_etcd_cmd="
    if [ -d '${etcd_cert_dir}' ]; then
      mkdir -p '${backup_path}/etcd'
      cp -a '${etcd_cert_dir}' '${backup_path}/etcd/ssl-backup'
      echo 'Etcd certificates backed up successfully'
    else
      echo 'Warning: Etcd certificate directory not found at ${etcd_cert_dir}'
      exit 1
    fi
  "

  if runner::remote_exec "${backup_etcd_cmd}"; then
    log::info "✓ Etcd certificates backed up"
    return 0
  else
    log::error "Failed to backup etcd certificates"
    return 1
  fi
}

_copy_backup_locally() {
  local remote_backup_path="$1"
  local local_backup_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}/cert-backups"

  mkdir -p "${local_backup_dir}"

  log::info "Copying backup to local directory: ${local_backup_dir}"

  # Try to copy the entire backup directory
  if runner::remote_copy_from "${remote_backup_path}" "${local_backup_dir}/$(basename ${remote_backup_path})" 2>/dev/null; then
    log::info "✓ Backup copied to local storage"
  else
    log::warn "Could not copy backup to local storage (non-critical)"
  fi
}

step::certs.backup.before.renew::rollback() {
  # Rollback would restore from backup if needed
  log::info "To restore from backup, manually copy files from backup directory"
  return 0
}

step::certs.backup.before.renew::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  # Backup on all control-plane and etcd nodes
  local nodes=""

  # Get control-plane nodes
  local cp_nodes
  cp_nodes=$(config::get_role_members 'control-plane' 2>/dev/null || true)
  if [[ -n "${cp_nodes}" ]]; then
    nodes="${cp_nodes}"
  fi

  # Get separate etcd nodes (if any)
  local etcd_nodes
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || true)
  if [[ -n "${etcd_nodes}" ]]; then
    nodes="${nodes}
${etcd_nodes}"
  fi

  # Remove duplicates and get IPs
  if [[ -n "${nodes}" ]]; then
    echo "${nodes}" | sort -u | while IFS= read -r node; do
      [[ -z "${node}" ]] && continue
      local node_ip
      node_ip=$(config::get_host_param "${node}" "address" 2>/dev/null || true)
      [[ -n "${node_ip}" ]] && echo "${node_ip}"
    done
  fi
}
