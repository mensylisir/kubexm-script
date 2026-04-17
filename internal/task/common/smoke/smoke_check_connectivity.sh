#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: smoke_check_connectivity
# 测试 Pod 连通性
# ==============================================================================


step::cluster.smoke.check.connectivity() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=cluster.smoke.check.connectivity] Testing pod connectivity..."

  local kubeconfig
  kubeconfig="$(context::get kubeconfig_path)"

  # 测试 DNS 解析
  if ! kubectl --kubeconfig="${kubeconfig}" exec nginx-smoke-test -n default -- nslookup kubernetes.default &>/dev/null; then
    logger::error "[host=${host} step=cluster.smoke.check.connectivity] DNS resolution failed"
    return 1
  fi

  # 测试 curl 到自身
  if ! kubectl --kubeconfig="${kubeconfig}" exec nginx-smoke-test -n default -- wget -q -O- http://127.0.0.1:80 &>/dev/null; then
    logger::error "[host=${host} step=cluster.smoke.check.connectivity] HTTP check failed"
    return 1
  fi

  logger::info "[host=${host} step=cluster.smoke.check.connectivity] Connectivity test passed"
  return 0
}

step::cluster.smoke.check.connectivity::run() {
  step::cluster.smoke.check.connectivity "$@"
}

step::cluster.smoke.check.connectivity::check() {
  return 1  # 总是执行
}

step::cluster.smoke.check.connectivity::rollback() { return 0; }

step::cluster.smoke.check.connectivity::targets() {
  # kubectl 操作仅需在本地执行（使用 kubeconfig），不针对特定主机
  return 0
}
