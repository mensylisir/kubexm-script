#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kh.render.haproxy.config::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local lb_dir
  lb_dir="$(context::get "lb_kh_haproxy_dir" || true)"
  if [[ -n "${lb_dir}" && -f "${lb_dir}/haproxy.cfg" ]]; then
    return 0
  fi
  return 1
}

step::lb.external.kubexm.kh.render.haproxy.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local lb_dir backend_servers
  lb_dir="$(context::get "lb_kh_haproxy_dir" || true)"
  backend_servers="$(context::get "lb_kh_haproxy_backends" || true)"

  local haproxy_cfg
  haproxy_cfg="global
  log stdout local0
  daemon

defaults
  mode tcp
  timeout connect 5s
  timeout client 50s
  timeout server 50s

frontend kubernetes-frontend
  bind *:6443
  default_backend kubernetes-apiserver

backend kubernetes-apiserver
  mode tcp
  balance roundrobin
${backend_servers}"
  printf '%s\n' "${haproxy_cfg}" > "${lb_dir}/haproxy.cfg"
}

step::lb.external.kubexm.kh.render.haproxy.config::rollback() { return 0; }

step::lb.external.kubexm.kh.render.haproxy.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
