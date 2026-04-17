#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - kube-vip
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_kube_vip() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.kube.vip.collect:${KUBEXM_ROOT}/internal/step/loadbalancer/kube-vip/collect.sh" \
    "lb.kube.vip.render.static.pod:${KUBEXM_ROOT}/internal/step/loadbalancer/kube-vip/render_static_pod.sh" \
    "lb.kube.vip.copy.static.pod:${KUBEXM_ROOT}/internal/step/loadbalancer/kube-vip/copy_static_pod.sh" \
    "lb.kube.vip.render.daemonset:${KUBEXM_ROOT}/internal/step/loadbalancer/kube-vip/render_daemonset.sh" \
    "lb.kube.vip.apply.daemonset:${KUBEXM_ROOT}/internal/step/loadbalancer/kube-vip/apply_daemonset.sh"
}

task::delete_kube_vip() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.kube.vip.delete:${KUBEXM_ROOT}/internal/step/loadbalancer/kube-vip/delete.sh"
}

export -f task::install_kube_vip
export -f task::delete_kube_vip