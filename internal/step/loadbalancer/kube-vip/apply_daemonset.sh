#!/usr/bin/env bash
set -euo pipefail

step::lb.kube.vip.apply.daemonset::check() {
  # Check if kube-vip daemonset is already deployed
  if kubectl get daemonset kube-vip-ds -n kube-system &>/dev/null; then
    return 0  # already deployed, skip
  fi
  return 1  # need to apply
}

step::lb.kube.vip.apply.daemonset::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local deploy_mode
  deploy_mode="$(context::get "lb_kube_vip_deploy_mode" || true)"
  if [[ "${deploy_mode}" != "daemon-set" ]]; then
    return 0
  fi

  local ds_file
  ds_file="$(context::get "lb_kube_vip_daemonset_file" || true)"
  if [[ -z "${ds_file}" ]]; then
    log::error "Missing kube-vip daemonset file"
    return 1
  fi

  if ! kubectl apply -f "${ds_file}"; then
    log::error "Failed to deploy Kube-VIP DaemonSet"
    return 1
  fi
  log::info "Kube-VIP DaemonSet deployed"
}

step::lb.kube.vip.apply.daemonset::rollback() { return 0; }

step::lb.kube.vip.apply.daemonset::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}