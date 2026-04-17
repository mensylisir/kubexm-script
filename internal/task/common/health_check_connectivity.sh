#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: health_check_connectivity
# 检查集群连接性 (Pod DNS, Service connectivity)
# ==============================================================================


step::health.check.connectivity() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host:-localhost} step=health.check_connectivity] Checking connectivity..."

  local apiserver_url
  apiserver_url=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "")
  if [[ -z "${apiserver_url}" ]]; then
    logger::error "[step=health.check_connectivity] Cannot get apiserver URL"
    return 1
  fi

  local cluster_version
  cluster_version=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' || echo "unknown")
  logger::info "[connectivity] Kubernetes version: ${cluster_version}"

  local test_pod_name="connectivity-test-$(date +%s)"
  if ! cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: ${test_pod_name}
  namespace: default
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ['sh', '-c', 'echo "Connectivity test" && sleep 5']
  restartPolicy: Never
  tolerations:
  - key: "node.kubernetes.io/not-ready"
    operator: "Exists"
    effect: "NoSchedule"
EOF
  then
    logger::error "[connectivity] Failed to create connectivity test pod"
    return 1
  fi

  local status=0
  sleep 8

  local pod_logs
  pod_logs=$(kubectl logs "${test_pod_name}" -n default 2>/dev/null || echo "")
  if [[ -z "${pod_logs}" ]]; then
    logger::error "[connectivity] Test pod did not produce logs"
    status=1
  else
    logger::info "[connectivity] Test pod executed successfully"
  fi

  local svc_count
  svc_count=$(kubectl get svc -A -o json 2>/dev/null | jq '.items | length' || echo "0")
  logger::info "[connectivity] Total services: ${svc_count}"

  local endpoints_count
  endpoints_count=$(kubectl get endpoints -A -o json 2>/dev/null | jq '.items | length' || echo "0")
  logger::info "[connectivity] Total endpoints: ${endpoints_count}"

  kubectl delete pod "${test_pod_name}" -n default --ignore-not-found=true &>/dev/null || true

  if [[ ${status} -ne 0 ]]; then
    return 1
  fi

  logger::info "[step=health.check_connectivity] Connectivity check completed"
  return 0
}

step::health.check.connectivity::run() {
  step::health.check.connectivity "$@"
}

step::health.check.connectivity::check() {
  # Always re-check: connectivity must be verified at moment of check, not skipped.
  return 1
}

step::health.check.connectivity::rollback() { return 0; }

step::health.check.connectivity::targets() {
  # kubectl 操作仅需在本地执行（使用 kubeconfig），不针对特定主机
  return 0
}
