#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Error Handling
# ==============================================================================
# 错误处理工具库
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 加载依赖
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"

# 错误代码定义
readonly ERR_GENERIC=1
readonly ERR_CONFIG=2
readonly ERR_NETWORK=3
readonly ERR_PERMISSION=4
readonly ERR_DEPENDENCY=5
readonly ERR_TIMEOUT=6
readonly ERR_VALIDATION=7
readonly ERR_DOWNLOAD=8
readonly ERR_INSTALL=9

#######################################
# 退出并记录错误
# Arguments:
#   $1 - 错误代码
#   $2 - 错误消息
# Returns:
#   无（退出进程）
#######################################
errors::die() {
  local exit_code="$1"
  local message="$2"

  log::error "$message"
  exit "$exit_code"
}

#######################################
# 检查上一个命令是否失败
# Arguments:
#   $1 - 错误代码（可选）
#   $2 - 错误消息（可选）
# Returns:
#   0 成功, 1 失败
#######################################
errors::check_last_error() {
  local exit_code="${1:-$ERR_GENERIC}"
  local message="${2:-Command failed with exit code ${exit_code}.}"

  # Note: $? captured AFTER local declarations would always be 0.
  # Check the explicit exit_code parameter instead.
  if [[ "${exit_code}" -ne 0 ]]; then
    log::error "$message"
    return 1
  fi
  return 0
}

#######################################
# 验证参数是否存在
# Arguments:
#   $1 - 参数名
#   $2 - 参数值
#   $3 - 错误消息（可选）
# Returns:
#   0 存在, 1 不存在
#######################################
errors::validate_required() {
  local param_name="$1"
  local param_value="$2"
  local error_msg="${3:-Parameter $param_name is required}"

  if [[ -z "$param_value" ]]; then
    log::error "$error_msg"
    return 1
  fi
  return 0
}

#######################################
# 验证文件是否存在
# Arguments:
#   $1 - 文件路径
#   $2 - 错误消息（可选）
# Returns:
#   0 存在, 1 不存在
#######################################
errors::validate_file() {
  local file="$1"
  local error_msg="${2:-File not found: $file}"

  if [[ ! -f "$file" ]]; then
    log::error "$error_msg"
    return 1
  fi
  return 0
}

#######################################
# 验证目录是否存在
# Arguments:
#   $1 - 目录路径
#   $2 - 错误消息（可选）
# Returns:
#   0 存在, 1 不存在
#######################################
errors::validate_dir() {
  local dir="$1"
  local error_msg="${2:-Directory not found: $dir}"

  if [[ ! -d "$dir" ]]; then
    log::error "$error_msg"
    return 1
  fi
  return 0
}

#######################################
# 验证命令是否存在
# Arguments:
#   $1 - 命令名
#   $2 - 错误消息（可选）
# Returns:
#   0 存在, 1 不存在
#######################################
errors::validate_command() {
  local cmd="$1"
  local error_msg="${2:-Command not found: $cmd}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log::error "$error_msg"
    return 1
  fi
  return 0
}

#######################################
# 验证数值范围
# Arguments:
#   $1 - 值
#   $2 - 最小值
#   $3 - 最大值
#   $4 - 错误消息（可选）
# Returns:
#   0 在范围内, 1 不在
#######################################
errors::validate_range() {
  local value="$1"
  local min="$2"
  local max="$3"
  local error_msg="${4:-Value $value is not in range [$min, $max]}"

  if [[ "$value" -lt "$min" || "$value" -gt "$max" ]]; then
    log::error "$error_msg"
    return 1
  fi
  return 0
}

#######################################
# 捕获信号并处理
# Arguments:
#   $1 - 信号名
#   $2 - 处理函数
# Returns:
#   0 成功, 1 失败
#######################################
#######################################
# 重试执行命令
# Arguments:
#   $1 - 最大重试次数
#   $2 - 重试间隔（秒）
#   $3... - 要执行的命令
# Returns:
#   0 成功, 1 失败
#######################################
errors::retry() {
  local max_attempts="$1"
  local delay="$2"
  shift 2

  local attempt=1
  while [[ $attempt -le $max_attempts ]]; do
    log::info "Attempt $attempt of $max_attempts..."

    if "$@"; then
      log::success "Command succeeded on attempt $attempt"
      return 0
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      log::warn "Command failed, retrying in $delay seconds..."
      sleep "$delay"
    fi

    ((attempt++)) || true
  done

  log::error "Command failed after $max_attempts attempts"
  return 1
}

#######################################
# 设置超时
# Arguments:
#   $1 - 超时时间（秒）
#   $2 - 要执行的函数
# Returns:
#   0 成功, 1 超时
#######################################
errors::with_timeout() {
  local timeout="$1"
  shift

  # 在后台执行命令
  ("$@") &
  local pid=$!

  # 等待超时
  local count=0
  while kill -0 "$pid" 2>/dev/null; do
    if [[ $count -ge $timeout ]]; then
      log::error "Command timed out after $timeout seconds"
      kill "$pid" 2>/dev/null
      return $ERR_TIMEOUT
    fi
    sleep 1
    ((count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  done

  # 等待进程结束
  wait "$pid" 2>/dev/null
  return $?
}

#######################################
# 记录堆栈跟踪
# Arguments:
#   无
# Returns:
#   无
#######################################
errors::print_stack_trace() {
  log::error "Stack trace:"
  local frame=0
  while caller $frame; do
    ((frame++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  done
}

# 导出函数
export -f errors::die
export -f errors::check_last_error
export -f errors::validate_required
export -f errors::validate_file
export -f errors::validate_dir
export -f errors::validate_command
export -f errors::validate_range
export -f errors::retry
export -f errors::with_timeout
export -f errors::print_stack_trace
