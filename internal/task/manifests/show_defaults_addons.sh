#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.defaults.addons::check() { return 1; }

step::manifests.show.defaults.addons::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local k8s_version
  k8s_version="$(context::get "manifests_k8s_version" || true)"
  local addon_nodelocaldns addon_metrics_server addon_ingress addon_storage
  addon_nodelocaldns="$(context::get "manifests_addon_nodelocaldns" || echo "false")"
  addon_metrics_server="$(context::get "manifests_addon_metrics_server" || echo "false")"
  addon_ingress="$(context::get "manifests_addon_ingress" || echo "false")"
  addon_storage="$(context::get "manifests_addon_storage" || echo "false")"

  echo "  插件配置:"
  echo "    - CoreDNS: $(versions::get coredns "$k8s_version" || defaults::get_coredns_version)"
  if [[ "${addon_metrics_server}" == "true" ]]; then
    echo "    - Metrics Server: $(versions::get "metrics-server" "$k8s_version" || defaults::get_metrics_server_version)"
  fi
  if [[ "${addon_ingress}" == "true" ]]; then
    local ingress_type
    ingress_type=$(config::get_ingress_type)
    if [[ "$ingress_type" == "traefik" ]]; then
      echo "    - Traefik: $(versions::get traefik "$k8s_version" || defaults::get_traefik_version)"
    else
      echo "    - Ingress NGINX: $(versions::get ingress-nginx "$k8s_version" || defaults::get_ingress_nginx_version)"
    fi
  fi
  if [[ "${addon_nodelocaldns}" == "true" ]]; then
    echo "    - NodeLocalDNS: $(versions::get nodelocaldns "$k8s_version" || defaults::get_nodelocaldns_version)"
  fi
  if [[ "${addon_storage}" == "true" ]]; then
    echo "    - Local Path Provisioner: $(versions::get local-path-provisioner "$k8s_version" || defaults::get_local_path_version)"
  fi
  echo
}

step::manifests.show.defaults.addons::rollback() { return 0; }

step::manifests.show.defaults.addons::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
