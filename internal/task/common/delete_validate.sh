#!/usr/bin/env bash
set -euo pipefail

step::cluster.delete.validate::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  # Check if cluster is accessible
  if kubectl cluster-info >/dev/null 2>&1; then
    return 1  # cluster exists, need to validate
  fi
  return 0  # cluster not accessible, skip validation
}

step::cluster.delete.validate::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local force="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      -f|--force)
        force="true"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for delete cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  if ! kubectl cluster-info >/dev/null 2>&1; then
    if [[ "${force}" == "true" ]]; then
      log::warn "Cluster is not accessible; proceeding with local cleanup only (--force)"
      return 0
    fi
    log::error "Cluster is not accessible or does not exist"
    log::error "Use --force to continue with local cleanup only"
    return 1
  fi

  local nodes
  nodes=$(kubectl get nodes -o name 2>/dev/null | sed 's/node\\///g' || echo "")
  if [[ -z "${nodes}" ]]; then
    log::warn "No nodes found in cluster"
  else
    log::info "Found nodes: ${nodes}"
  fi

  if [[ "${force}" != "true" ]]; then
    log::warn "This will permanently delete the cluster and all data"
    log::info "Use --force to skip confirmation"
    read -p "Are you sure you want to delete the cluster? (yes/no): " confirm
    if [[ "${confirm}" != "yes" ]]; then
      log::info "Delete operation cancelled"
      return 1
    fi
  fi
}

step::cluster.delete.validate::rollback() { return 0; }

step::cluster.delete.validate::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
