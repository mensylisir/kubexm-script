#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - haproxy systemd (internal mode, kubexm)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_lb_haproxy_systemd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.internal.haproxy.systemd.collect.identity:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/collect_identity.sh" \
    "lb.internal.haproxy.systemd.collect.backends:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/collect_backends.sh" \
    "lb.internal.haproxy.systemd.render.config:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/render_config.sh" \
    "lb.internal.haproxy.systemd.render.service:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/render_service.sh" \
    "lb.internal.haproxy.systemd.prepare.dirs:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/prepare_dirs.sh" \
    "lb.internal.haproxy.systemd.copy.config:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/copy_config.sh" \
    "lb.internal.haproxy.systemd.copy.service:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/copy_service.sh" \
    "lb.internal.haproxy.systemd.enable:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/systemd.sh"
}

task::delete_lb_haproxy_systemd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.internal.haproxy.systemd.delete:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/delete.sh"
}

export -f task::install_lb_haproxy_systemd
export -f task::delete_lb_haproxy_systemd