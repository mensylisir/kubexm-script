#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kubelet.render.config::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local config_dir
  config_dir="$(context::get "kubelet_config_dir" || true)"
  if [[ -n "${config_dir}" && -f "${config_dir}/config.yaml" ]]; then
    return 0
  fi
  return 1
}

step::kubernetes.kubelet.render.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local cluster_name node_name cluster_domain cluster_dns_ip max_pods cgroup_driver config_dir
  cluster_name="$(context::get "kubelet_cluster_name" || true)"
  node_name="$(context::get "kubelet_node_name" || true)"
  cluster_domain="$(context::get "kubelet_cluster_domain" || true)"
  cluster_dns_ip="$(context::get "kubelet_cluster_dns_ip" || true)"
  max_pods="$(context::get "kubelet_max_pods" || true)"
  cgroup_driver="$(context::get "kubelet_cgroup_driver" || true)"
  config_dir="$(context::get "kubelet_config_dir" || true)"

  template::render_with_vars \
    "${KUBEXM_ROOT}/templates/kubernetes/kubelet/kubelet-binary-config.yaml.tmpl" \
    "${config_dir}/config.yaml" \
    "CLUSTER_NAME=${cluster_name}" \
    "NODE_NAME=${node_name}" \
    "CLUSTER_DNS_IP=${cluster_dns_ip}" \
    "CLUSTER_DOMAIN=${cluster_domain}" \
    "KUBELET_MAX_PODS=${max_pods}" \
    "CGROUP_DRIVER=${cgroup_driver}"
}

step::kubernetes.kubelet.render.config::rollback() { return 0; }

step::kubernetes.kubelet.render.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
