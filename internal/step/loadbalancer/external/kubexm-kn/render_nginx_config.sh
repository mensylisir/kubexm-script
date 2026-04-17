#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kn.render.nginx.config::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local lb_dir
  lb_dir="$(context::get "lb_kn_nginx_dir" || true)"
  if [[ -n "${lb_dir}" && -f "${lb_dir}/nginx.conf" ]]; then
    return 0
  fi
  return 1
}

step::lb.external.kubexm.kn.render.nginx.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local lb_dir upstream_servers
  lb_dir="$(context::get "lb_kn_nginx_dir" || true)"
  upstream_servers="$(context::get "lb_kn_nginx_upstream" || true)"

  local nginx_cfg
  nginx_cfg="events {
    worker_connections 1024;
}
stream {
    upstream kube_apiserver {
${upstream_servers}
    }
    server {
        listen 6443;
        proxy_pass kube_apiserver;
        proxy_timeout 3s;
        proxy_connect_timeout 1s;
    }
}"
  printf '%s\n' "${nginx_cfg}" > "${lb_dir}/nginx.conf"
}

step::lb.external.kubexm.kn.render.nginx.config::rollback() { return 0; }

step::lb.external.kubexm.kn.render.nginx.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
