#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.update.lb.render.nginx::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local lb_skip lb_type
  lb_skip="$(context::get "scale_lb_skip" || echo "false")"
  if [[ "${lb_skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi

  lb_type="$(context::get "scale_lb_type" || config::get_loadbalancer_type)"
  if [[ "${lb_type}" != "nginx" ]]; then
    return 0  # not nginx type, skip
  fi

  return 1  # need to render nginx config
}

step::cluster.scale.update.lb.render.nginx::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/utils/loadbalancer.sh"

  local lb_skip lb_type
  lb_skip="$(context::get "scale_lb_skip" || echo "false")"
  if [[ "${lb_skip}" == "true" ]]; then
    return 0
  fi

  lb_type="$(context::get "scale_lb_type" || config::get_loadbalancer_type)"
  if [[ "${lb_type}" != "nginx" ]]; then
    return 0
  fi

  local worker_nodes first_master
  worker_nodes="$(context::get "scale_lb_worker_nodes" || true)"
  first_master="$(context::get "scale_lb_first_master" || true)"
  if [[ -z "${first_master}" ]]; then
    log::error "Missing control-plane node for Nginx update"
    return 1
  fi

  log::info "Updating Nginx upstream configuration..."
  loadbalancer::generate_config "${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}/${first_master}/loadbalancer" "nginx" "${worker_nodes}" "6443"
}

step::cluster.scale.update.lb.render.nginx::rollback() { return 0; }

step::cluster.scale.update.lb.render.nginx::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
