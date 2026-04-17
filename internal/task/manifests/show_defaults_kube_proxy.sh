#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.defaults.kube.proxy::check() { return 1; }

step::manifests.show.defaults.kube.proxy::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  echo "  Kube-Proxy配置:"
  echo "    - 模式: $(defaults::get_kube_proxy_mode) (高性能负载均衡)"
  echo "    - 调度算法: $(defaults::get_kube_proxy_scheduler) (轮询)"
  echo "    - StrictARP: $(defaults::get_kube_proxy_strict_arp)"
  echo
}

step::manifests.show.defaults.kube.proxy::rollback() { return 0; }

step::manifests.show.defaults.kube.proxy::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
