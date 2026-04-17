#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Health JSON Output Helper
# ==============================================================================

health::output_json() {
  local check_type="$1"
  local exit_code="$2"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local status="healthy"
  [[ ${exit_code} -ne 0 ]] && status="unhealthy"

  cat <<EOF
{
  "cluster": "${KUBEXM_CLUSTER_NAME:-unknown}",
  "check_type": "${check_type}",
  "status": "${status}",
  "exit_code": ${exit_code},
  "timestamp": "${timestamp}",
  "details": {
    "nodes": $(health::_json_nodes 2>/dev/null || echo '{}'),
    "components": $(health::_json_components 2>/dev/null || echo '{}'),
    "workloads": $(health::_json_workloads 2>/dev/null || echo '{}')
  }
}
EOF
}

health::_json_nodes() {
  local nodes
  nodes=$(kubectl get nodes -o json 2>/dev/null || echo '{"items":[]}')
  local total ready not_ready
  total=$(echo "${nodes}" | jq '.items | length' 2>/dev/null || echo 0)
  ready=$(echo "${nodes}" | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length' 2>/dev/null || echo 0)
  not_ready=$((total - ready))
  echo "{\"total\": ${total}, \"ready\": ${ready}, \"not_ready\": ${not_ready}}"
}

health::_json_components() {
  local components="{}"
  # 检查关键组件
  local kubelet_status="unknown"
  if systemctl is-active kubelet &>/dev/null; then
    kubelet_status="active"
  elif systemctl is-active kubelet &>/dev/null; then
    kubelet_status="inactive"
  fi
  echo "{\"kubelet\": \"${kubelet_status}\"}"
}

health::_json_workloads() {
  local pods
  pods=$(kubectl get pods -n kube-system -o json 2>/dev/null || echo '{"items":[]}')
  local total running pending failed
  total=$(echo "${pods}" | jq '.items | length' 2>/dev/null || echo 0)
  running=$(echo "${pods}" | jq '[.items[] | select(.status.phase=="Running")] | length' 2>/dev/null || echo 0)
  pending=$(echo "${pods}" | jq '[.items[] | select(.status.phase=="Pending")] | length' 2>/dev/null || echo 0)
  failed=$(echo "${pods}" | jq '[.items[] | select(.status.phase=="Failed")] | length' 2>/dev/null || echo 0)
  echo "{\"total\": ${total}, \"running\": ${running}, \"pending\": ${pending}, \"failed\": ${failed}}"
}

export -f health::output_json
