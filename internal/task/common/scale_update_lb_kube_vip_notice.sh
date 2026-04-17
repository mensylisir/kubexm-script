#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.update.lb.kube.vip.notice::check() { return 1; }

step::cluster.scale.update.lb.kube.vip.notice::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local lb_skip lb_type
  lb_skip="$(context::get "scale_lb_skip" || echo "false")"
  if [[ "${lb_skip}" == "true" ]]; then
    return 0
  fi

  lb_type="$(context::get "scale_lb_type" || config::get_loadbalancer_type)"
  if [[ "${lb_type}" == "kube-vip" ]]; then
    log::info "Kube-VIP does not require manual update"
  fi
}

step::cluster.scale.update.lb.kube.vip.notice::rollback() { return 0; }

step::cluster.scale.update.lb.kube.vip.notice::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
