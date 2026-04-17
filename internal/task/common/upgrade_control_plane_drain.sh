#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.control.plane.drain::check() { return 1; }

step::cluster.upgrade.control.plane.drain::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local node_name
  node_name="$(context::get "cluster_upgrade_node_name")"

  log::info "Upgrading control plane node: ${node_name}"
  kubectl drain "${node_name}" --ignore-daemonsets --delete-emptydir-data --force || true
}

step::cluster.upgrade.control.plane.drain::rollback() { return 0; }

step::cluster.upgrade.control.plane.drain::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
