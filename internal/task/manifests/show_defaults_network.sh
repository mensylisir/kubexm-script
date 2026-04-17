#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.defaults.network::check() { return 1; }

step::manifests.show.defaults.network::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local addon_nodelocaldns
  addon_nodelocaldns="$(context::get "manifests_addon_nodelocaldns" || echo "false")"

  echo "  网络设置:"
  echo "    - Service CIDR: $(defaults::get_service_cidr)"
  echo "    - Pod CIDR: $(defaults::get_pod_cidr)"
  echo "    - 集群域名: $(defaults::get_cluster_domain)"

  if [[ "${addon_nodelocaldns}" == "true" ]]; then
    echo "    - DNS服务IP: $(defaults::get_nodelocaldns_ip) (NodeLocalDNS)"
  else
    echo "    - DNS服务IP: $(defaults::get_cluster_dns_ip)"
  fi
  echo
}

step::manifests.show.defaults.network::rollback() { return 0; }

step::manifests.show.defaults.network::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
