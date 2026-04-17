#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.nginx.systemd.render.config::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local lb_dir
  lb_dir="$(context::get "lb_internal_nginx_systemd_dir" || true)"
  if [[ -n "${lb_dir}" && -f "${lb_dir}/nginx.conf" ]]; then
    return 0
  fi
  return 1
}

step::lb.internal.nginx.systemd.render.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local lb_dir upstream_servers
  lb_dir="$(context::get "lb_internal_nginx_systemd_dir" || true)"
  upstream_servers="$(context::get "lb_internal_nginx_systemd_upstream" || true)"

  # NOTE: 使用 <<"EOF" 防止 heredoc 内容被双展开，允许 ${upstream_servers} 正常展开，
  # 但阻止 $(cmd)/`cmd` 等命令替换被意外执行
  local nginx_cfg
  nginx_cfg=$(cat << "EOF"
events {
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
}
EOF
  )
  printf '%s\n' "${nginx_cfg}" > "${lb_dir}/nginx.conf"
}

step::lb.internal.nginx.systemd.render.config::rollback() { return 0; }

step::lb.internal.nginx.systemd.render.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
# Alias for static pod mode
step::lb.internal.nginx.static.render.config::check() { step::lb.internal.nginx.systemd.render.config::check "$@"; }
step::lb.internal.nginx.static.render.config::run() { step::lb.internal.nginx.systemd.render.config::run "$@"; }
step::lb.internal.nginx.static.render.config::rollback() { step::lb.internal.nginx.systemd.render.config::rollback "$@"; }
step::lb.internal.nginx.static.render.config::targets() { step::lb.internal.nginx.systemd.render.config::targets "$@"; }
