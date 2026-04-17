#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kube.proxy.collect.settings::check() { return 1; }

step::kubernetes.kube.proxy.collect.settings::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local pod_cidr proxy_mode proxy_strict_arp proxy_scheduler
  pod_cidr=$(config::get_pod_cidr)
  proxy_mode=$(config::get "spec.kubernetes.kube_proxy.mode" "$(defaults::get_kube_proxy_mode)")
  proxy_strict_arp=$(config::get "spec.kubernetes.kube_proxy.strict_arp" "$(defaults::get_kube_proxy_strict_arp)")
  proxy_scheduler=$(config::get "spec.kubernetes.kube_proxy.scheduler" "$(defaults::get_kube_proxy_scheduler)")

  context::set "kube_proxy_pod_cidr" "${pod_cidr}"
  context::set "kube_proxy_mode" "${proxy_mode}"
  context::set "kube_proxy_strict_arp" "${proxy_strict_arp}"
  context::set "kube_proxy_scheduler" "${proxy_scheduler}"
}

step::kubernetes.kube.proxy.collect.settings::rollback() { return 0; }

step::kubernetes.kube.proxy.collect.settings::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
