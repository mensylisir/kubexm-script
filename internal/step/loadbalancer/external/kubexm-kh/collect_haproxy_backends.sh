#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kh.collect.haproxy.backends::check() { return 1; }

step::lb.external.kubexm.kh.collect.haproxy.backends::run() {
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

  local backend_servers="" idx=1 master master_ip
  for master in ${master_nodes}; do
    master_ip=$(config::get_host_param "${master}" "address")
    [[ -z "${master_ip}" ]] && continue
    backend_servers+="  server master${idx} ${master_ip}:6443 check"$'\n'
    ((idx++)) || true
  done

  context::set "lb_kh_haproxy_backends" "${backend_servers%$'\n'}"
}

step::lb.external.kubexm.kh.collect.haproxy.backends::rollback() { return 0; }

step::lb.external.kubexm.kh.collect.haproxy.backends::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
