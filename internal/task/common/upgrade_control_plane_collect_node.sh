#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.control.plane.collect.node::check() { return 1; }

step::cluster.upgrade.control.plane.collect.node::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local master_nodes
  master_nodes=$(config::get_role_members 'control-plane')
  if [[ -z "${master_nodes}" ]]; then
    log::error "No control-plane nodes found"
    return 1
  fi

  local first_master
  first_master=$(echo "${master_nodes}" | awk '{print $1}')
  local first_master_ip
  first_master_ip=$(config::get_host_param "${first_master}" "address")

  local node_name="" node
  for node in ${master_nodes}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  context::set "cluster_upgrade_first_master_ip" "${first_master_ip}"
  context::set "cluster_upgrade_node_name" "${node_name}"
}

step::cluster.upgrade.control.plane.collect.node::rollback() { return 0; }

step::cluster.upgrade.control.plane.collect.node::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
