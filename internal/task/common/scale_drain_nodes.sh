#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.drain.nodes::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  local action=""
  action="$(defaults::get_scale_action)"
  if [[ "${action}" != "scale-in" ]]; then
    return 0  # not scale-in, skip
  fi
  return 1  # scale-in action, need to drain
}

step::cluster.scale.drain.nodes::run() {
  local ctx="$1"
  shift
  local action="" nodes_to_remove=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
      --nodes=*) nodes_to_remove="${arg#*=}" ;;
    esac
  done
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-in" ]]; then
    return 0
  fi
  if [[ -z "${nodes_to_remove}" ]]; then
    log::error "No nodes specified for scale-in operation"
    return 1
  fi

  IFS=',' read -ra NODE_ARRAY <<< "${nodes_to_remove}"
  local node
  for node in "${NODE_ARRAY[@]}"; do
    log::info "Draining node: ${node}"
    if ! kubectl get node "${node}" &>/dev/null; then
      log::warn "Node not found: ${node}"
      continue
    fi
    if ! kubectl drain "${node}" --delete-emptydir-data --ignore-daemonsets --force --timeout=300s; then
      log::error "Failed to drain node: ${node}"
      return 1
    fi
  done
}

step::cluster.scale.drain.nodes::rollback() { return 0; }

step::cluster.scale.drain.nodes::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
