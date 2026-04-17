#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Log System
# ==============================================================================
# 提供日志记录功能，支持结构化输出
# ==============================================================================

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 当前日志级别（默认INFO）
export KUBEXM_LOG_LEVEL=${KUBEXM_LOG_LEVEL:-1}

# 日志输出模式: text (default) | json
export KUBEXM_LOG_FORMAT=${KUBEXM_LOG_FORMAT:-text}

# 日志文件路径（可选）
export KUBEXM_LOG_FILE=${KUBEXM_LOG_FILE:-}

# 日志前缀
LOG_PREFIX="[KubeXM]"

# 日志颜色
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# 上下文信息（可被 log::set_context 设置）
LOG_CONTEXT_HOST="${KUBEXM_HOST:-}"
LOG_CONTEXT_STEP="${KUBEXM_STEP_NAME:-}"
LOG_CONTEXT_PIPELINE="${KUBEXM_PIPELINE:-}"
LOG_CONTEXT_TASK="${KUBEXM_TASK:-}"

#######################################
# 设置日志上下文
# 用法: log::set_context <host> <step> <pipeline> <task>
#######################################
log::set_context() {
  LOG_CONTEXT_HOST="${1:-}"
  LOG_CONTEXT_STEP="${2:-}"
  LOG_CONTEXT_PIPELINE="${3:-}"
  LOG_CONTEXT_TASK="${4:-}"
}

#######################################
# 清除日志上下文
#######################################
log::clear_context() {
  LOG_CONTEXT_HOST=""
  LOG_CONTEXT_STEP=""
  LOG_CONTEXT_PIPELINE=""
  LOG_CONTEXT_TASK=""
}

#######################################
# JSON 结构化日志输出
#######################################
log::json_output() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  # 构建 JSON 对象
  local json="{\"timestamp\":\"${timestamp}\",\"level\":\"${level}\",\"message\":\"$(echo "${message}" | sed 's/"/\\"/g')\""
  [[ -n "${LOG_CONTEXT_HOST}" ]] && json="${json},\"host\":\"${LOG_CONTEXT_HOST}\""
  [[ -n "${LOG_CONTEXT_STEP}" ]] && json="${json},\"step\":\"${LOG_CONTEXT_STEP}\""
  [[ -n "${LOG_CONTEXT_PIPELINE}" ]] && json="${json},\"pipeline\":\"${LOG_CONTEXT_PIPELINE}\""
  [[ -n "${LOG_CONTEXT_TASK}" ]] && json="${json},\"task\":\"${LOG_CONTEXT_TASK}\""
  json="${json}}"

  echo "${json}" >&2
}

#######################################
# 文本格式日志输出
#######################################
log::text_output() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local prefix

  case "${level}" in
    DEBUG)
      prefix="${COLOR_BLUE}[DEBUG]${COLOR_RESET}"
      ;;
    INFO)
      prefix="${COLOR_GREEN}[INFO]${COLOR_RESET}"
      ;;
    WARN)
      prefix="${COLOR_YELLOW}[WARN]${COLOR_RESET}"
      ;;
    ERROR)
      prefix="${COLOR_RED}[ERROR]${COLOR_RESET}"
      ;;
    SUCCESS)
      prefix="${COLOR_GREEN}[SUCCESS]${COLOR_RESET}"
      ;;
    *)
      prefix="${COLOR_BLUE}[LOG]${COLOR_RESET}"
      ;;
  esac

  # 添加上下文信息
  local context=""
  if [[ -n "${LOG_CONTEXT_HOST}" ]]; then
    context="host=${LOG_CONTEXT_HOST} "
  fi
  if [[ -n "${LOG_CONTEXT_STEP}" ]]; then
    context="${context}step=${LOG_CONTEXT_STEP} "
  fi

  if [[ -n "${context}" ]]; then
    echo -e "${timestamp} ${LOG_PREFIX} ${prefix} [${context}] ${message}" >&2
  else
    echo -e "${timestamp} ${LOG_PREFIX} ${prefix} ${message}" >&2
  fi
}

#######################################
# 主日志输出函数
#######################################
log::output() {
  local level="$1"
  local message="$2"

  if [[ "${KUBEXM_LOG_FORMAT}" == "json" ]]; then
    log::json_output "${level}" "${message}"
  else
    log::text_output "${level}" "${message}"
  fi

  # 同时写入日志文件（如果配置）
  if [[ -n "${KUBEXM_LOG_FILE}" ]]; then
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo "${timestamp} [${level}] ${message}" >> "${KUBEXM_LOG_FILE}"
  fi
}

#######################################
# 输出DEBUG级别日志
#######################################
log::debug() {
  if [[ ${KUBEXM_LOG_LEVEL} -le ${LOG_LEVEL_DEBUG} ]]; then
    log::output "DEBUG" "$1"
  fi
}

#######################################
# 输出INFO级别日志
#######################################
log::info() {
  if [[ ${KUBEXM_LOG_LEVEL} -le ${LOG_LEVEL_INFO} ]]; then
    log::output "INFO" "$1"
  fi
}

#######################################
# 输出WARN级别日志
#######################################
log::warn() {
  if [[ ${KUBEXM_LOG_LEVEL} -le ${LOG_LEVEL_WARN} ]]; then
    log::output "WARN" "$1"
  fi
}

#######################################
# 输出ERROR级别日志
#######################################
log::error() {
  if [[ ${KUBEXM_LOG_LEVEL} -le ${LOG_LEVEL_ERROR} ]]; then
    log::output "ERROR" "$1"
  fi
}

#######################################
# 输出SUCCESS级别日志
#######################################
log::success() {
  if [[ ${KUBEXM_LOG_LEVEL} -le ${LOG_LEVEL_INFO} ]]; then
    log::output "SUCCESS" "$1"
  fi
}

# 导出函数
export -f log::set_context
export -f log::clear_context
export -f log::debug
export -f log::info
export -f log::warn
export -f log::error
export -f log::success
