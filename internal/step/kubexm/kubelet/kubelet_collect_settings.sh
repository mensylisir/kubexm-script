#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kubelet.collect.settings::check() { return 1; }

step::kubernetes.kubelet.collect.settings::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local cluster_domain cluster_dns_ip max_pods cgroup_driver
  cluster_domain=$(config::get_cluster_domain)
  cluster_dns_ip=$(config::get "spec.kubernetes.cluster_dns_ip" "$(defaults::get_cluster_dns_ip)" 2>/dev/null || defaults::get_cluster_dns_ip)
  max_pods=$(config::get "spec.kubernetes.kubelet.max_pods" "110")
  cgroup_driver=$(config::get "spec.runtime.cgroup_driver" "systemd")

  context::set "kubelet_cluster_domain" "${cluster_domain}"
  context::set "kubelet_cluster_dns_ip" "${cluster_dns_ip}"
  context::set "kubelet_max_pods" "${max_pods}"
  context::set "kubelet_cgroup_driver" "${cgroup_driver}"
}

step::kubernetes.kubelet.collect.settings::rollback() { return 0; }

step::kubernetes.kubelet.collect.settings::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
