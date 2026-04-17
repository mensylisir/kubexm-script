#!/usr/bin/env bash
set -euo pipefail

step::manifests.collect.from.cluster.values::check() { return 1; }

step::manifests.collect.from.cluster.values::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local cluster_name
  cluster_name="$(context::get "manifests_cluster_name" || true)"
  if [[ -z "$cluster_name" ]]; then
    return 0
  fi

  local k8s_version k8s_type etcd_type runtime cni arch
  k8s_version=$(config::get_kubernetes_version)
  k8s_type=$(config::get_kubernetes_type)
  etcd_type=$(config::get_etcd_type)
  runtime=$(config::get_runtime_type)
  cni=$(config::get_network_plugin)
  arch=$(config::get_arch_list)

  local lb_enabled lb_mode lb_type
  lb_enabled=$(config::get_loadbalancer_enabled)
  lb_mode=$(config::get_loadbalancer_mode)
  lb_type=$(config::get_loadbalancer_type)

  local addon_metrics_server addon_ingress addon_storage addon_nodelocaldns
  addon_metrics_server=$(config::get "spec.addons.metrics_server.enabled" "false")
  addon_ingress=$(config::get "spec.addons.ingress_controller.enabled" "false")
  addon_storage=$(config::get "spec.addons.storage.local_path_provisioner.enabled" "false")
  addon_nodelocaldns=$(config::get "spec.addons.nodelocaldns.enabled" "false")

  context::set "manifests_k8s_version" "${k8s_version}"
  context::set "manifests_k8s_type" "${k8s_type}"
  context::set "manifests_etcd_type" "${etcd_type}"
  context::set "manifests_runtime" "${runtime}"
  context::set "manifests_cni" "${cni}"
  context::set "manifests_arch" "${arch}"
  context::set "manifests_lb_enabled" "${lb_enabled}"
  context::set "manifests_lb_mode" "${lb_mode}"
  context::set "manifests_lb_type" "${lb_type}"
  context::set "manifests_addon_metrics_server" "${addon_metrics_server}"
  context::set "manifests_addon_ingress" "${addon_ingress}"
  context::set "manifests_addon_storage" "${addon_storage}"
  context::set "manifests_addon_nodelocaldns" "${addon_nodelocaldns}"
}

step::manifests.collect.from.cluster.values::rollback() { return 0; }

step::manifests.collect.from.cluster.values::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
