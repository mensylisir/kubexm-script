#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Retry Utility for Pipeline/Module Layer
# ==============================================================================
# 为关键操作提供统一的重试能力（指数退避）
# ==============================================================================

source "${KUBEXM_ROOT}/internal/logger/log.sh"

# 默认配置
KUBEXM_RETRY_MAX_ATTEMPTS="${KUBEXM_RETRY_MAX_ATTEMPTS:-3}"
KUBEXM_RETRY_BASE_DELAY="${KUBEXM_RETRY_BASE_DELAY:-2}"
KUBEXM_RETRY_MAX_DELAY="${KUBEXM_RETRY_MAX_DELAY:-30}"

#######################################
# 带指数退避的重试
# Arguments:
#   $1 - 描述标签 (如 "SSH connect", "download")
#   $2 - 最大重试次数 (默认 3)
#   $3 - 基础延迟秒数 (默认 2)
#   $4.. - 要执行的命令
# Returns:
#   0 成功, 1 所有重试耗尽
#######################################
retry::with_backoff() {
  local label="$1"
  local max_attempts="${2:-${KUBEXM_RETRY_MAX_ATTEMPTS}}"
  local base_delay="${3:-${KUBEXM_RETRY_BASE_DELAY}}"
  shift 3

  local attempt=1
  local delay

  while [[ ${attempt} -le ${max_attempts} ]]; do
    if "$@"; then
      if [[ ${attempt} -gt 1 ]]; then
        log::info "${label} succeeded on attempt ${attempt}/${max_attempts}"
      fi
      return 0
    fi

    if [[ ${attempt} -lt ${max_attempts} ]]; then
      # 指数退避: base_delay * 2^(attempt-1)，上限 max_delay
      delay=$(( base_delay * (1 << (attempt - 1)) ))
      [[ ${delay} -gt ${KUBEXM_RETRY_MAX_DELAY} ]] && delay=${KUBEXM_RETRY_MAX_DELAY}
      log::warn "${label} failed (attempt ${attempt}/${max_attempts}), retrying in ${delay}s..."
      sleep "${delay}"
    else
      log::error "${label} failed after ${max_attempts} attempts"
    fi
    ((attempt++)) || true
  done

  return 1
}

#######################################
# Pipeline 级 Module 调用重试包装
# 用法: retry::module 3 5 module::download "${ctx}" "$@"
# Arguments:
#   $1 - 最大重试次数
#   $2 - 基础延迟秒数
#   $3.. - module 函数调用
#######################################
retry::module() {
  local max_attempts="$1"
  local base_delay="$2"
  shift 2

  local func_name="$1"
  retry::with_backoff "Module ${func_name}" "${max_attempts}" "${base_delay}" "$@"
}

export -f retry::with_backoff
export -f retry::module
