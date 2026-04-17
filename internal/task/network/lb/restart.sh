#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - Restart
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::restart_haproxy() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.restart.haproxy:${KUBEXM_ROOT}/internal/step/loadbalancer/haproxy/restart.sh"
}

task::restart_nginx() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.restart.nginx:${KUBEXM_ROOT}/internal/step/loadbalancer/nginx/restart_nginx.sh"
}

task::restart_keepalived() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.restart.keepalived:${KUBEXM_ROOT}/internal/step/loadbalancer/keepalived/keepalived.sh"
}

export -f task::restart_haproxy
export -f task::restart_nginx
export -f task::restart_keepalived
