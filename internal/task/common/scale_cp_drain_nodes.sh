#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cp.drain.nodes::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  return 1  # need to drain
}

step::cluster.scale.cp.drain.nodes::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  local node_name
  node_name="$(context::get "cluster_scale_cp_node" || true)"
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  log::info "Draining control-plane node: ${node_name}"
  if ! kubectl get node "${node_name}" &>/dev/null; then
    log::warn "Node not found: ${node_name}"
    return 0
  fi
  if ! kubectl drain "${node_name}" --delete-emptydir-data --ignore-daemonsets --force --timeout=300s; then
    log::error "Failed to drain node: ${node_name}"
    return 1
  fi
}

step::cluster.scale.cp.drain.nodes::rollback() { return 0; }

step::cluster.scale.cp.drain.nodes::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}