#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: health_check_components
# 检查 K8s 组件状态 (kubelet, kube-proxy, etcd)
# ==============================================================================


step::health.check.components() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host:-localhost} step=health.check_components] Checking component status..."

  # 检查 kubelet 服务状态
  local kubelet_status
  kubelet_status=$(systemctl is-active kubelet 2>/dev/null || echo "unknown")
  if [[ "${kubelet_status}" == "active" ]]; then
    logger::info "[component=kubelet] Status: active"
  else
    logger::error "[component=kubelet] Status: ${kubelet_status}"
    return 1
  fi

  # 检查 kube-proxy Pod 状态
  local kube_proxy_ns="kube-system"
  local kube_proxy_ready
  kube_proxy_ready=$(kubectl get daemonset kube-proxy -n "${kube_proxy_ns}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  local kube_proxy_desired
  kube_proxy_desired=$(kubectl get daemonset kube-proxy -n "${kube_proxy_ns}" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")

  if [[ "${kube_proxy_ready}" == "${kube_proxy_desired}" && "${kube_proxy_desired}" != "0" ]]; then
    logger::info "[component=kube-proxy] Ready: ${kube_proxy_ready}/${kube_proxy_desired}"
  else
    logger::error "[component=kube-proxy] Not ready: ${kube_proxy_ready}/${kube_proxy_desired}"
    return 1
  fi

  # 检查 etcd 状态
  local etcd_health
  etcd_health=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  if [[ "${etcd_health}" == "True" ]]; then
    logger::info "[component=etcd] Status: healthy"
  else
    logger::error "[component=etcd] Status: ${etcd_health}"
    return 1
  fi

  # 检查 kube-apiserver
  local apiserver_health
  apiserver_health=$(kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  if [[ "${apiserver_health}" == "True" ]]; then
    logger::info "[component=kube-apiserver] Status: healthy"
  else
    logger::error "[component=kube-apiserver] Status: ${apiserver_health}"
    return 1
  fi

  logger::info "[step=health.check_components] All components are healthy"
  return 0
}

step::health.check.components::run() {
  step::health.check.components "$@"
}

step::health.check.components::check() {
  # Always re-check: health verification must reflect current state, not cached result.
  return 1
}

step::health.check.components::rollback() { return 0; }

step::health.check.components::targets() {
  # kubectl 操作仅需在本地执行（使用 kubeconfig），不针对特定主机
  return 0
}
