#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cp.join.exec::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip execution
  fi
  return 1  # need to execute join
}

step::cluster.scale.cp.join.exec::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  local node_name join_command
  node_name="$(context::get "cluster_scale_cp_node" || true)"
  join_command="$(context::get "cluster_scale_cp_cmd" || true)"

  if [[ -z "${join_command}" ]]; then
    log::error "No join command found for control-plane node"
    return 1
  fi

  runner::remote_exec "${join_command}"
  log::info "Control-plane node ${node_name} joined successfully"
}

step::cluster.scale.cp.join.exec::rollback() { return 0; }

step::cluster.scale.cp.join.exec::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}