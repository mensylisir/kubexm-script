#!/usr/bin/env bash
set -euo pipefail

step::manifests.collect.from.cluster.normalize::check() { return 1; }

step::manifests.collect.from.cluster.normalize::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local cluster_name
  cluster_name="$(context::get "manifests_cluster_name" || true)"
  if [[ -z "$cluster_name" ]]; then
    return 0
  fi

  local lb_enabled lb_mode lb_type
  lb_enabled="$(context::get "manifests_lb_enabled" || true)"
  lb_mode="$(context::get "manifests_lb_mode" || true)"
  lb_type="$(context::get "manifests_lb_type" || true)"

  local addon_metrics_server addon_ingress addon_storage addon_nodelocaldns
  addon_metrics_server="$(context::get "manifests_addon_metrics_server" || true)"
  addon_ingress="$(context::get "manifests_addon_ingress" || true)"
  addon_storage="$(context::get "manifests_addon_storage" || true)"
  addon_nodelocaldns="$(context::get "manifests_addon_nodelocaldns" || true)"

  lb_enabled=$(echo "$lb_enabled" | tr '[:upper:]' '[:lower:]')
  addon_metrics_server=$(echo "$addon_metrics_server" | tr '[:upper:]' '[:lower:]')
  addon_ingress=$(echo "$addon_ingress" | tr '[:upper:]' '[:lower:]')
  addon_storage=$(echo "$addon_storage" | tr '[:upper:]' '[:lower:]')
  addon_nodelocaldns=$(echo "$addon_nodelocaldns" | tr '[:upper:]' '[:lower:]')

  if [[ "$lb_mode" == "kube-vip" ]]; then
    lb_type="kube-vip"
  fi
  export KUBEXM_LB_ENABLED="$lb_enabled"
  export KUBEXM_LB_MODE="$lb_mode"
  export KUBEXM_LB_TYPE="$lb_type"

  context::set "manifests_lb_enabled" "${lb_enabled}"
  context::set "manifests_lb_type" "${lb_type}"
  context::set "manifests_addon_metrics_server" "${addon_metrics_server}"
  context::set "manifests_addon_ingress" "${addon_ingress}"
  context::set "manifests_addon_storage" "${addon_storage}"
  context::set "manifests_addon_nodelocaldns" "${addon_nodelocaldns}"
}

step::manifests.collect.from.cluster.normalize::rollback() { return 0; }

step::manifests.collect.from.cluster.normalize::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
