#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.kube.proxy.render.config::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local config_dir
  config_dir="$(context::get "kube_proxy_config_dir" || true)"
  if [[ -n "${config_dir}" && -f "${config_dir}/kube-proxy-config.yaml" ]]; then
    return 0
  fi
  return 1
}

step::kubernetes.kube.proxy.render.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local cluster_name node_name pod_cidr proxy_mode proxy_strict_arp proxy_scheduler config_dir
  cluster_name="$(context::get "kube_proxy_cluster_name" || true)"
  node_name="$(context::get "kube_proxy_node_name" || true)"
  pod_cidr="$(context::get "kube_proxy_pod_cidr" || true)"
  proxy_mode="$(context::get "kube_proxy_mode" || true)"
  proxy_strict_arp="$(context::get "kube_proxy_strict_arp" || true)"
  proxy_scheduler="$(context::get "kube_proxy_scheduler" || true)"
  config_dir="$(context::get "kube_proxy_config_dir" || true)"

  template::render_with_vars \
    "${KUBEXM_ROOT}/templates/kubernetes/kube-proxy/kube-proxy-config.yaml.tmpl" \
    "${config_dir}/kube-proxy-config.yaml" \
    "CLUSTER_NAME=${cluster_name}" \
    "NODE_NAME=${node_name}" \
    "POD_CIDR=${pod_cidr}" \
    "PROXY_MODE=${proxy_mode}" \
    "PROXY_IPVS_STRICT_ARP=${proxy_strict_arp}" \
    "PROXY_IPVS_SCHEDULER=${proxy_scheduler}"
}

step::kubernetes.kube.proxy.render.config::rollback() { return 0; }

step::kubernetes.kube.proxy.render.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
