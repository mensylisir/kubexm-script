#!/usr/bin/env bash
set -euo pipefail

step::lb.kube.vip.collect::check() { return 1; }

step::lb.kube.vip.collect::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local vip_address deploy_mode interface
  vip_address=$(config::get_loadbalancer_vip)
  deploy_mode=$(config::get_loadbalancer_deploy_mode "static-pod")
  interface=$(config::get_loadbalancer_interface)

  if [[ -z "${vip_address}" ]]; then
    log::error "loadbalancer vip is required for kube-vip mode"
    return 1
  fi

  local master_nodes
  master_nodes=$(config::get_role_members 'control-plane')
  if [[ -z "${master_nodes}" ]]; then
    log::error "No control-plane nodes found for kube-vip"
    return 1
  fi

  context::set "lb_kube_vip_vip" "${vip_address}"
  context::set "lb_kube_vip_deploy_mode" "${deploy_mode}"
  context::set "lb_kube_vip_interface" "${interface}"
  context::set "lb_kube_vip_master_nodes" "${master_nodes}"
  context::set "lb_kube_vip_first_master" "$(echo "${master_nodes}" | awk '{print $1}')"
}

step::lb.kube.vip.collect::rollback() { return 0; }

step::lb.kube.vip.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}