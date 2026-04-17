#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.nginx.systemd.collect.upstream::check() { return 1; }

step::lb.internal.nginx.systemd.collect.upstream::run() {
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

  context::set "lb_internal_nginx_systemd_upstream" "${upstream_servers%$'\n'}"
}

step::lb.internal.nginx.systemd.collect.upstream::rollback() { return 0; }

step::lb.internal.nginx.systemd.collect.upstream::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
# Alias for static pod mode
step::lb.internal.nginx.static.collect.upstream::check() { step::lb.internal.nginx.systemd.collect.upstream::check "$@"; }
step::lb.internal.nginx.static.collect.upstream::run() { step::lb.internal.nginx.systemd.collect.upstream::run "$@"; }
step::lb.internal.nginx.static.collect.upstream::rollback() { step::lb.internal.nginx.systemd.collect.upstream::rollback "$@"; }
step::lb.internal.nginx.static.collect.upstream::targets() { step::lb.internal.nginx.systemd.collect.upstream::targets "$@"; }
