#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: smoke_cleanup
# 清理测试 Pod
# ==============================================================================


step::cluster.smoke.cleanup() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=cluster.smoke.cleanup] Cleaning up test pod..."

  local kubeconfig
  kubeconfig="$(context::get kubeconfig_path)"

  kubectl --kubeconfig="${kubeconfig}" delete pod nginx-smoke-test -n default --ignore-not-found &>/dev/null || true

  logger::info "[host=${host} step=cluster.smoke.cleanup] Cleanup completed"
  return 0
}

step::cluster.smoke.cleanup::run() {
  step::cluster.smoke.cleanup "$@"
}

step::cluster.smoke.cleanup::check() {
  return 1  # 总是执行
}

step::cluster.smoke.cleanup::rollback() { return 0; }

step::cluster.smoke.cleanup::targets() {
  # kubectl 操作仅需在本地执行（使用 kubeconfig），不针对特定主机
  return 0
}
