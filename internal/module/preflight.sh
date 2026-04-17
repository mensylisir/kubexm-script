#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Preflight Module
# ==============================================================================
# 系统预检模块，包含：
# Task: SystemCheck - 系统检查（CPU、内存、磁盘）
# Task: OSInit - 系统初始化（Swap、防火墙、内核参数、基础包）
# Task: TimeSync - 时间同步
# Task: ConnectivityCheck - 连通性检查
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/infra/system_check/main.sh"
source "${KUBEXM_ROOT}/internal/task/infra/os_init.sh"
source "${KUBEXM_ROOT}/internal/task/infra/time_sync.sh"

# ==============================================================================
# Connectivity Check - 连通性检查
# ==============================================================================

# 获取所有主机的 IP 列表
module::preflight::get_all_ips() {
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local nodes out=""
  nodes=$(config::get_all_host_names)
  for node in ${nodes}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -n "${node_ip}" ]] && out+="${node_ip} "
  done
  echo "${out}"
}

# -----------------------------------------------------------------------------
# Task: ConnectivityCheck - 连通性检查（严格模式，创建/升级前）
# 所有主机必须可达；任一不可达则整个 pipeline 失败
# -----------------------------------------------------------------------------
module::preflight_connectivity_strict() {
  local ctx="$1"
  shift

  logger::info "[PreFlight] Checking host connectivity (strict mode)..."

  local ips
  ips=$(module::preflight::get_all_ips)
  [[ -z "${ips}" ]] && {
    logger::error "[PreFlight] No hosts found"
    return 1
  }

  # 通过 task::run_steps 调用 preflight.check.host step（自动遍历所有主机）
  # step targets() 返回所有主机，每台执行 SSH echo 测试
  # 任意一台不可达则 task 失败，整个 pipeline 中止
  task::run_steps "${ctx}" -- \
    "preflight.check.host:${KUBEXM_ROOT}/internal/step/preflight/preflight_check_host.sh"

  logger::info "[PreFlight] All hosts reachable"
  return 0
}

# -----------------------------------------------------------------------------
# Task: ConnectivityCheck - 连通性检查（宽松模式，删除/扩缩容前）
# 允许部分主机不可达，仅记录警告，不阻塞流程
# -----------------------------------------------------------------------------
module::preflight_connectivity_permissive() {
  local ctx="$1"
  shift

  logger::info "[PreFlight] Checking host connectivity (permissive mode)..."

  local ips
  ips=$(module::preflight::get_all_ips)
  [[ -z "${ips}" ]] && {
    logger::warn "[PreFlight] No hosts found"
    return 0
  }

  # 宽松模式：尝试连通性检查，失败只记录警告不阻塞
  # Use a temp file to capture results from subshell
  local result_file
  result_file=$(mktemp)
  
  set +e
  task::run_steps "${ctx}" -- \
    "preflight.check.host:${KUBEXM_ROOT}/internal/step/preflight/preflight_check_host.sh" \
    > "${result_file}" 2>&1
  local run_result=$?
  set -e

  # Parse results
  local total=0 reachable=0 unreachable=0
  if [[ -f "${result_file}" ]]; then
    total=$(grep -c '\[host=' "${result_file}" 2>/dev/null || echo "0")
    if [[ ${run_result} -eq 0 ]]; then
      reachable=${total}
    else
      # Some hosts failed - count them
      unreachable=$(grep -c 'FAILED\|unreachable\|connection refused' "${result_file}" 2>/dev/null || echo "0")
      reachable=$((total - unreachable))
    fi
    rm -f "${result_file}"
  fi

  if [[ ${unreachable} -gt 0 ]]; then
    logger::warn "[PreFlight] ${unreachable}/${total} hosts unreachable (continuing in permissive mode)"
  else
    logger::info "[PreFlight] All ${total} hosts reachable"
  fi
  
  # Permissive mode always succeeds
  return 0
}

# -----------------------------------------------------------------------------
# Task: SystemCheck - 系统检查
# -----------------------------------------------------------------------------
module::preflight_check() {
  local ctx="$1"
  shift
  task::system_check "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# Task: OSInit - 系统初始化
# -----------------------------------------------------------------------------
module::preflight_os_init() {
  local ctx="$1"
  shift
  task::os_init "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# Task: TimeSync - 时间同步
# -----------------------------------------------------------------------------
module::preflight_time_sync() {
  local ctx="$1"
  shift
  task::time_sync "${ctx}" "$@"
}

# -----------------------------------------------------------------------------
# 完整 Preflight 流程
# -----------------------------------------------------------------------------
module::preflight() {
  local ctx="$1"
  shift

  logger::info "[Module:preflight] SystemCheck..."
  module::preflight_check "${ctx}" "$@" || return $?

  logger::info "[Module:preflight] OSInit..."
  module::preflight_os_init "${ctx}" "$@" || return $?

  logger::info "[Module:preflight] TimeSync..."
  module::preflight_time_sync "${ctx}" "$@"
}

export -f module::preflight_check
export -f module::preflight_os_init
export -f module::preflight_time_sync
export -f module::preflight
export -f module::preflight_connectivity_strict
export -f module::preflight_connectivity_permissive
