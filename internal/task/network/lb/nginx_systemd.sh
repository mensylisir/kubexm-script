#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - nginx systemd (internal mode, kubexm)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_lb_nginx_systemd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.internal.nginx.systemd.collect.identity:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/collect_identity.sh" \
    "lb.internal.nginx.systemd.collect.upstream:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/collect_upstream.sh" \
    "lb.internal.nginx.systemd.render.config:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/render_config.sh" \
    "lb.internal.nginx.systemd.render.service:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/render_service.sh" \
    "lb.internal.nginx.systemd.prepare.dirs:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/prepare_dirs.sh" \
    "lb.internal.nginx.systemd.copy.config:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/copy_config.sh" \
    "lb.internal.nginx.systemd.copy.service:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/copy_service.sh" \
    "lb.internal.nginx.systemd.enable:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/systemd.sh"
}

task::delete_lb_nginx_systemd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.internal.nginx.systemd.delete:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/delete.sh"
}

export -f task::install_lb_nginx_systemd
export -f task::delete_lb_nginx_systemd