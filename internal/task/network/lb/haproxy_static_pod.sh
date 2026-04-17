#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - haproxy static pod (internal mode, kubeadm)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_lb_haproxy_static_pod() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.internal.haproxy.static.prepare.dirs:${KUBEXM_ROOT}/internal/step/loadbalancer/internal_static_prepare_dirs.sh" \
    "lb.internal.haproxy.static.collect.identity:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/collect_identity.sh" \
    "lb.internal.haproxy.static.collect.backends:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/collect_backends.sh" \
    "lb.internal.haproxy.static.render.config:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/render_config.sh" \
    "lb.internal.haproxy.static.collect.pod.dir:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/collect_pod_dir.sh" \
    "lb.internal.haproxy.static.render.pod:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/render_pod.sh" \
    "lb.internal.haproxy.static.copy.config:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/copy_config.sh" \
    "lb.internal.haproxy.static.copy.pod:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/copy_pod.sh"
}

task::delete_lb_haproxy_static_pod() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.internal.haproxy.static.delete:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/delete.sh"
}

export -f task::install_lb_haproxy_static_pod
export -f task::delete_lb_haproxy_static_pod