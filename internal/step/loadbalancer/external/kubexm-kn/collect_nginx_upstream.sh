#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kn.collect.nginx.upstream::check() { return 1; }

step::lb.external.kubexm.kn.collect.nginx.upstream::run() {
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

  local upstream_servers="" master master_ip
  for master in ${master_nodes}; do
    master_ip=$(config::get_host_param "${master}" "address")
    [[ -z "${master_ip}" ]] && continue
    upstream_servers+="        server ${master_ip}:6443;"$'\n'
  done

  context::set "lb_kn_nginx_upstream" "${upstream_servers%$'\n'}"
}

step::lb.external.kubexm.kn.collect.nginx.upstream::rollback() { return 0; }

step::lb.external.kubexm.kn.collect.nginx.upstream::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
