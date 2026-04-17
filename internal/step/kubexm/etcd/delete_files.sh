#!/usr/bin/env bash
set -euo pipefail

step::etcd.delete.files::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  if [[ "${etcd_type}" == "exists" ]]; then
    return 0  # etcd_type=exists means skip deletion
  fi
  # Check if etcd directories exist
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/var/lib/etcd" 2>/dev/null; then
    return 1  # files exist, need to delete
  fi
  return 0
}

step::etcd.delete.files::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  if [[ "${etcd_type}" == "exists" ]]; then
    log::info "Skipping etcd deletion (etcd_type=exists)..."
    return 0
  fi

  log::info "Deleting etcd files on ${KUBEXM_HOST}..."
  runner::remote_exec "rm -rf /var/lib/etcd/* && rm -rf /etc/etcd/ssl/* && rm -rf /etc/etcd/*.yml /etc/etcd/*.yaml 2>/dev/null || true"
}

step::etcd.delete.files::rollback() { return 0; }

step::etcd.delete.files::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}