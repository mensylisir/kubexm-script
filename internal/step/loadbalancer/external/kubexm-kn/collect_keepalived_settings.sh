#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kn.collect.keepalived.settings::check() { return 1; }

step::lb.external.kubexm.kn.collect.keepalived.settings::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local lb_nodes vip interface
  lb_nodes=$(config::get_role_members 'loadbalancer')
  vip=$(config::get_loadbalancer_vip)
  interface=$(config::get_loadbalancer_interface)

  if [[ -z "${lb_nodes}" ]]; then
    log::error "No loadbalancer nodes found"
    return 1
  fi
  if [[ -z "${vip}" ]]; then
    log::error "loadbalancer vip is required for external mode"
    return 1
  fi
  if [[ -z "${interface}" ]]; then
    log::error "loadbalancer interface is required for external mode"
    return 1
  fi

  local node_index=0 state="BACKUP" priority=100 node_ip unicast_peers=""
  local node
  for node in ${lb_nodes}; do
    node_index=$((node_index + 1))
    node_ip=$(config::get_host_param "${node}" "address")
    unicast_peers="${unicast_peers}    ${node_ip}\n"
    if [[ "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      priority=$((100 - node_index))
      if [[ ${node_index} -eq 1 ]]; then
        state="MASTER"
        priority=120
      fi
      break
    fi
  done

  local router_id auth_pass
  router_id=$(config::get "spec.loadbalancer.keepalived.virtual_router_id" 2>/dev/null || echo "")
  auth_pass=$(config::get "spec.loadbalancer.keepalived.auth_pass" 2>/dev/null || echo "")

  context::set "lb_kn_keepalived_vip" "${vip}"
  context::set "lb_kn_keepalived_interface" "${interface}"
  context::set "lb_kn_keepalived_state" "${state}"
  context::set "lb_kn_keepalived_priority" "${priority}"
  context::set "lb_kn_keepalived_node_index" "${node_index}"
  context::set "lb_kn_keepalived_unicast_peers" "$(echo -e "${unicast_peers}")"
  context::set "lb_kn_keepalived_router_id" "${router_id}"
  context::set "lb_kn_keepalived_auth_pass" "${auth_pass}"
}

step::lb.external.kubexm.kn.collect.keepalived.settings::rollback() { return 0; }

step::lb.external.kubexm.kn.collect.keepalived.settings::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
