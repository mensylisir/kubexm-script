#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: preflight.check.host
# 主机连通性检查（通过 SSH echo 测试）
# check: 如果主机可达则 skip
# run:   无需操作（连通性检查为只读验证）
# targets: 返回所有集群主机
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

# 从配置获取所有主机 IP
_preflight_check_host_get_ips() {
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local nodes out=""
  nodes=$(config::get_all_host_names 2>/dev/null || true)
  for node in ${nodes}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address" 2>/dev/null || true)
    [[ -n "${node_ip}" ]] && out+="${node_ip}"$'\n'
  done
  echo "${out}"
}

step::preflight.check.host::check() {
  local ctx="${1:-}"
  shift

  # 获取当前执行主机（从 KUBEXM_HOST）
  local host="${KUBEXM_HOST:-}"
  if [[ -z "${host}" ]]; then
    return 0  # 无 host 信息则跳过
  fi

  # 执行 SSH 连通性测试
  if timeout 5 bash -c '
    source "${KUBEXM_ROOT}/internal/runner/runner.sh"
    KUBEXM_HOST="$1"
    runner::remote_exec "echo ok" >/dev/null 2>&1
  ' _ "${host}"; then
    return 0  # 主机可达，跳过
  fi

  return 1  # 主机不可达
}

step::preflight.check.host::run() {
  # 连通性检查为只读验证，run 无需实际操作
  return 0
}

step::preflight.check.host::rollback() { return 0; }

step::preflight.check.host::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  _preflight_check_host_get_ips
}
