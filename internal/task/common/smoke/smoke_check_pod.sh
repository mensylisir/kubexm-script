#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: smoke_check_pod
# 等待 Pod Running 状态
# ==============================================================================


step::cluster.smoke.check.pod() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=cluster.smoke.check.pod] Waiting for test pod to be Running..."

  local kubeconfig
  kubeconfig="$(context::get kubeconfig_path)"

  local max_attempts=30
  local attempt=0

  while [[ ${attempt} -lt ${max_attempts} ]]; do
    local phase
    phase=$(kubectl --kubeconfig="${kubeconfig}" get pod nginx-smoke-test -n default -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

    case "${phase}" in
      Running)
        logger::info "[host=${host} step=cluster.smoke.check.pod] Pod is Running"
        return 0
        ;;
      Failed|Error)
        logger::error "[host=${host} step=cluster.smoke.check.pod] Pod failed: ${phase}"
        return 1
        ;;
      NotFound|"")
        logger::warn "[host=${host} step=cluster.smoke.check.pod] Pod not found yet..."
        ;;
      *)
        logger::debug "[host=${host} step=cluster.smoke.check.pod] Current phase: ${phase}"
        ;;
    esac

    attempt=$((attempt + 1))
    sleep 5
  done

  logger::error "[host=${host} step=cluster.smoke.check.pod] Timeout waiting for pod"
  return 1
}

step::cluster.smoke.check.pod::run() {
  step::cluster.smoke.check.pod "$@"
}

step::cluster.smoke.check.pod::check() {
  return 1  # 总是执行
}

step::cluster.smoke.check.pod::rollback() { return 0; }

step::cluster.smoke.check.pod::targets() {
  # kubectl 操作仅需在本地执行（使用 kubeconfig），不针对特定主机
  return 0
}
