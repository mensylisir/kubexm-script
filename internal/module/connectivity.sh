#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Connectivity Check Module
# ==============================================================================
# 在每个 pipeline 前执行，确保所有目标主机 SSH 可达
# 支持两种模式：
#   strict: 所有主机必须可达，否则失败（用于 create/upgrade/cert renew）
#   permissive: 允许部分主机不可达，仅警告（用于 delete/scale/health/backup/restore）
# ==============================================================================

source "${KUBEXM_ROOT}/internal/logger/log.sh"

# -----------------------------------------------------------------------------
# 严格模式：所有主机必须可达
# -----------------------------------------------------------------------------
module::connectivity_check_strict() {
  local ctx="$1"
  shift

  log::info "[Connectivity] Checking all hosts reachability (strict mode)..."

  local all_hosts
  all_hosts=$(config::get_all_host_addresses 2>/dev/null || true)

  if [[ -z "${all_hosts}" ]]; then
    log::warn "[Connectivity] No hosts found in configuration, skipping"
    return 0
  fi

  local failed_hosts=()
  local host
  for host in ${all_hosts}; do
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes root@"${host}" "echo ok" >/dev/null 2>&1; then
      failed_hosts+=("${host}")
    fi
  done

  if [[ ${#failed_hosts[@]} -gt 0 ]]; then
    log::error "[Connectivity] The following hosts are unreachable:"
    local h
    for h in "${failed_hosts[@]}"; do
      log::error "  - ${h}"
    done
    log::error "[Connectivity] Strict mode: all hosts must be reachable. Aborting."
    return 1
  fi

  log::info "[Connectivity] All hosts reachable"
  return 0
}

# -----------------------------------------------------------------------------
# 宽松模式：允许部分主机不可达
# -----------------------------------------------------------------------------
module::connectivity_check_permissive() {
  local ctx="$1"
  shift

  log::info "[Connectivity] Checking hosts reachability (permissive mode)..."

  local all_hosts
  all_hosts=$(config::get_all_host_addresses 2>/dev/null || true)

  if [[ -z "${all_hosts}" ]]; then
    log::warn "[Connectivity] No hosts found, skipping"
    return 0
  fi

  local unreachable=()
  local host
  for host in ${all_hosts}; do
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes root@"${host}" "echo ok" >/dev/null 2>&1; then
      unreachable+=("${host}")
    fi
  done

  if [[ ${#unreachable[@]} -gt 0 ]]; then
    log::warn "[Connectivity] The following hosts are unreachable (continuing anyway):"
    local h
    for h in "${unreachable[@]}"; do
      log::warn "  - ${h}"
    done
  fi

  return 0
}

export -f module::connectivity_check_strict
export -f module::connectivity_check_permissive
