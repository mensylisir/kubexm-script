#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - nginx static pod (internal mode, kubeadm)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_lb_nginx_static_pod() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.internal.nginx.static.prepare.dirs:${KUBEXM_ROOT}/internal/step/loadbalancer/internal_static_prepare_dirs.sh" \
    "lb.internal.nginx.static.collect.identity:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/collect_identity.sh" \
    "lb.internal.nginx.static.collect.upstream:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/collect_upstream.sh" \
    "lb.internal.nginx.static.render.config:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/render_config.sh" \
    "lb.internal.nginx.static.collect.pod.dir:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/collect_pod_dir.sh" \
    "lb.internal.nginx.static.render.pod:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/render_pod.sh" \
    "lb.internal.nginx.static.copy.config:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/copy_config.sh" \
    "lb.internal.nginx.static.copy.pod:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/copy_pod.sh"
}

task::delete_lb_nginx_static_pod() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.internal.nginx.static.delete:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/delete.sh"
}

export -f task::install_lb_nginx_static_pod
export -f task::delete_lb_nginx_static_pod