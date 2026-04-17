#!/usr/bin/env bash
set -euo pipefail

step::cluster.delete.node.drain::check() {
  local node="${KUBEXM_HOST}"
  if [[ -z "${node}" ]]; then
    return 1
  fi
  if kubectl get node "${node}" &>/dev/null; then
    return 1
  fi
  return 0
}

step::cluster.delete.node.drain::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local node="${KUBEXM_HOST}"
  if [[ -z "${node}" ]]; then
    log::error "Missing node name for drain"
    return 1
  fi

  log::info "Draining node ${node}..."
  kubectl drain "${node}" --delete-emptydir-data --ignore-daemonsets --timeout=60s >/dev/null 2>&1 || {
    log::warn "Failed to drain node ${node}, forcing delete..."
  }
}

step::cluster.delete.node.drain::rollback() { return 0; }

step::cluster.delete.node.drain::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  local nodes
  nodes=$(kubectl get nodes -o name 2>/dev/null | sed 's/node\\///g' || echo "")
  if [[ -z "${nodes}" ]]; then
    return 0
  fi
  local out=""
  local node
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    out+="${node} "
  done
  echo "${out}"
}
