#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.images::check() { return 1; }

step::manifests.show.images::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/image_manager.sh"

  local k8s_version arch k8s_type etcd_type cni lb_enabled lb_mode lb_type addon_nodelocaldns
  k8s_version="$(context::get "manifests_k8s_version" || true)"
  arch="$(context::get "manifests_arch" || true)"
  k8s_type="$(context::get "manifests_k8s_type" || true)"
  etcd_type="$(context::get "manifests_etcd_type" || true)"
  cni="$(context::get "manifests_cni" || true)"
  lb_enabled="$(context::get "manifests_lb_enabled" || true)"
  lb_mode="$(context::get "manifests_lb_mode" || true)"
  lb_type="$(context::get "manifests_lb_type" || true)"
  addon_nodelocaldns="$(context::get "manifests_addon_nodelocaldns" || echo "false")"

  echo "=== 容器镜像 ==="
  while IFS= read -r image; do
    echo "  - ${image}"
  done < <(generate_core_images "$k8s_version" "$arch" "$k8s_type" "$etcd_type" "$cni" "$lb_enabled" "$lb_mode" "$lb_type" "$addon_nodelocaldns")
}

step::manifests.show.images::rollback() { return 0; }

step::manifests.show.images::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
