#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.haproxy.systemd.render.config::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local lb_dir
  lb_dir="$(context::get "lb_internal_haproxy_systemd_dir" || true)"
  if [[ -n "${lb_dir}" && -f "${lb_dir}/haproxy.cfg" ]]; then
    return 0
  fi
  return 1
}

step::lb.internal.haproxy.systemd.render.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local lb_dir backend_servers
  lb_dir="$(context::get "lb_internal_haproxy_systemd_dir" || true)"
  backend_servers="$(context::get "lb_internal_haproxy_systemd_backends" || true)"

  # NOTE: 使用 <<"EOF" 防止 heredoc 内容被双展开，允许 ${backend_servers} 正常展开，
  # 但阻止 $(cmd)/`cmd` 等命令替换被意外执行
  local haproxy_cfg
  haproxy_cfg=$(cat << "EOF"
global
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
${backend_servers}
EOF
  )
  printf '%s\n' "${haproxy_cfg}" > "${lb_dir}/haproxy.cfg"
}

step::lb.internal.haproxy.systemd.render.config::rollback() { return 0; }

step::lb.internal.haproxy.systemd.render.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
# Alias for static pod mode
step::lb.internal.haproxy.static.render.config::check() { step::lb.internal.haproxy.systemd.render.config::check "$@"; }
step::lb.internal.haproxy.static.render.config::run() { step::lb.internal.haproxy.systemd.render.config::run "$@"; }
step::lb.internal.haproxy.static.render.config::rollback() { step::lb.internal.haproxy.systemd.render.config::rollback "$@"; }
step::lb.internal.haproxy.static.render.config::targets() { step::lb.internal.haproxy.systemd.render.config::targets "$@"; }
