#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.update.lb.collect.workers::check() { return 1; }

step::cluster.scale.update.lb.collect.workers::run() {
  local ctx="$1"
  shift
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi

  local lb_enabled lb_type
  lb_enabled=$(config::get_loadbalancer_enabled)
  lb_type=$(config::get_loadbalancer_type)
  context::set "scale_lb_enabled" "${lb_enabled}"
  context::set "scale_lb_type" "${lb_type}"

  if [[ "${lb_enabled}" != "true" ]]; then
    log::info "Load balancer is not enabled, skipping update"
    context::set "scale_lb_skip" "true"
    return 0
  fi

  context::set "scale_lb_skip" "false"

  local worker_nodes
  worker_nodes=$(kubectl get nodes -l node-role.kubernetes.io/worker -o name 2>/dev/null | sed 's/node\\///g' | tr '\n' ' ')
  log::info "Current worker nodes: ${worker_nodes}"
  context::set "scale_lb_worker_nodes" "${worker_nodes}"

  local first_master
  first_master=$(config::get_role_members 'control-plane' | head -1)
  if [[ -z "${first_master}" ]]; then
    log::error "No control-plane nodes found for load balancer update"
    return 1
  fi
  context::set "scale_lb_first_master" "${first_master}"
}

step::cluster.scale.update.lb.collect.workers::rollback() { return 0; }

step::cluster.scale.update.lb.collect.workers::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
