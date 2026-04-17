#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.precheck::check() { return 1; }

step::cluster.upgrade.precheck::run() {
  local ctx="$1"
  shift
  local target_version=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --to-version=*) target_version="${arg#*=}" ;;
    esac
  done
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  log::info "=== Running pre-upgrade checks ==="
  if [[ -n "${target_version}" ]]; then
    log::info "Target version: ${target_version}"
  fi

  if ! kubectl get nodes | grep -q "Ready"; then
    log::error "Cluster is not healthy, all nodes must be Ready before upgrade"
    return 1
  fi

  local system_pods
  system_pods=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
  if [[ ${system_pods} -gt 0 ]]; then
    log::warn "Found ${system_pods} non-running pods in kube-system namespace"
  fi

  log::info "Checking etcd backup..."
  local backup_dir="/var/backups/etcd"
  local recent_backup
  recent_backup=$(ls -t ${backup_dir}/etcd-snapshot-*.db 2>/dev/null | head -1 || true)
  if [[ -n "${recent_backup}" ]]; then
    local backup_age
    backup_age=$(( ($(date +%s) - $(stat -c %Y "${recent_backup}")) / 86400 ))
    if [[ ${backup_age} -gt 7 ]]; then
      log::warn "Last etcd backup is ${backup_age} days old. Recommend running backup before upgrade."
    else
      log::info "Recent etcd backup found: ${recent_backup}"
    fi
  else
    log::warn "No etcd backup found in ${backup_dir}. Recommend running backup before upgrade."
  fi

  log::info "Checking network connectivity..."
  local api_endpoint
  api_endpoint=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||' | cut -d: -f1)
  if [[ -n "${api_endpoint}" ]]; then
    if ping -c 1 -W 2 "${api_endpoint}" >/dev/null 2>&1; then
      log::info "API server endpoint ${api_endpoint} is reachable"
    else
      log::warn "Cannot ping API server endpoint ${api_endpoint}"
    fi
  fi

  log::success "=== Pre-upgrade checks completed ==="
}

step::cluster.upgrade.precheck::rollback() { return 0; }

step::cluster.upgrade.precheck::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
