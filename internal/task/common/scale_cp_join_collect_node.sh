#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cp.join.collect.node::check() { return 1; }

step::cluster.scale.cp.join.collect.node::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  [[ "${skip}" == "true" ]] && return 0

  local node_name=""
  local masters node node_ip
  masters=$(config::get_role_members 'control-plane')
  for node in ${masters}; do
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ -n "${node_ip}" && "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  context::set "cluster_scale_cp_node" "${node_name}"
}

step::cluster.scale.cp.join.collect.node::rollback() { return 0; }

step::cluster.scale.cp.join.collect.node::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}