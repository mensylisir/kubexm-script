#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: health_check_workloads
# 检查核心工作负载状态
# ==============================================================================


step::health.check.workloads() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host:-localhost} step=health.check_workloads] Checking workload status..."

  local ns="kube-system"

  # CoreDNS 检查
  local coredns_ready=0
  local coredns_desired=0
  if kubectl get deployment coredns -n "${ns}" &>/dev/null; then
    coredns_ready=$(kubectl get deployment coredns -n "${ns}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    coredns_desired=$(kubectl get deployment coredns -n "${ns}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
  fi

  if [[ "${coredns_ready}" == "${coredns_desired}" && "${coredns_desired}" != "0" ]]; then
    logger::info "[workload=coredns] Ready: ${coredns_ready}/${coredns_desired}"
  else
    logger::warn "[workload=coredns] Not ready: ${coredns_ready}/${coredns_desired}"
  fi

  # metrics-server 检查 (如果部署了)
  if kubectl get deployment metrics-server -n "${ns}" &>/dev/null; then
    local metrics_ready
    metrics_ready=$(kubectl get deployment metrics-server -n "${ns}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local metrics_desired
    metrics_desired=$(kubectl get deployment metrics-server -n "${ns}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    if [[ "${metrics_ready}" == "${metrics_desired}" && "${metrics_desired}" != "0" ]]; then
      logger::info "[workload=metrics-server] Ready: ${metrics_ready}/${metrics_desired}"
    else
      logger::warn "[workload=metrics-server] Not ready: ${metrics_ready}/${metrics_desired}"
    fi
  fi

  # 检查 kube-system 下非 completed 状态的 Pod
  local failed_pods
  failed_pods=$(kubectl get pods -n "${ns}" -o json | jq -r '.items[] | select(.status.phase!="Running" and .status.phase!="Succeeded") | "\(.metadata.name):\(.status.phase)"' 2>/dev/null || echo "")

  if [[ -n "${failed_pods}" ]]; then
    logger::warn "[step=health.check_workloads] Some pods in kube-system are not healthy:"
    echo "${failed_pods}" | while read -r pod; do
      logger::warn "[pod=${pod}]"
    done
  else
    logger::info "[step=health.check_workloads] All pods in kube-system are healthy"
  fi

  return 0
}

step::health.check.workloads::run() {
  step::health.check.workloads "$@"
}

step::health.check.workloads::check() {
  # Always re-check: workload status must reflect current state, not cached result.
  return 1
}

step::health.check.workloads::rollback() { return 0; }

step::health.check.workloads::targets() {
  # kubectl 操作仅需在本地执行（使用 kubeconfig），不针对特定主机
  return 0
}
