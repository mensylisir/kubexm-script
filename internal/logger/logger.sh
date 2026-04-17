#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Logger
# ==============================================================================
# 提供结构化日志记录功能（JSON + 彩色控制台）
# ==============================================================================

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 日志格式: json | text
export KUBEXM_LOG_FORMAT=${KUBEXM_LOG_FORMAT:-text}

# 日志文件路径
export KUBEXM_LOG_FILE=${KUBEXM_LOG_FILE:-}

logger::_escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\b'/\\b}"
  s="${s//$'\f'/\\f}"
  printf '%s' "${s}"
}

logger::_color_for_level() {
  local level="$1"
  case "${level}" in
    DEBUG) printf '\033[36m' ;;
    INFO) printf '\033[32m' ;;
    WARN) printf '\033[33m' ;;
    ERROR) printf '\033[31m' ;;
    SUCCESS) printf '\033[32m' ;;
    *) printf '\033[0m' ;;
  esac
}

logger::_emit() {
  local level="$1" msg="$2"
  local run_id="${KUBEXM_RUN_ID:-default}"
  local step_name="${KUBEXM_STEP_NAME:-}"
  local host="${KUBEXM_HOST:-}"
  local pipeline_name="${KUBEXM_PIPELINE_NAME:-}"
  local task_id="${KUBEXM_TASK_ID:-}"
  local timestamp
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  if [[ "${KUBEXM_LOG_FORMAT}" == "json" ]]; then
    local json
    json="{\"timestamp\":\"${timestamp}\",\"level\":\"${level}\",\"msg\":\"$(logger::_escape_json "${msg}")\",\"task_id\":\"${task_id}\",\"pipeline_name\":\"${pipeline_name}\",\"run_id\":\"${run_id}\",\"step_name\":\"${step_name}\",\"host\":\"${host}\"}"
    echo "${json}" >&2
  else
    local color reset
    color="$(logger::_color_for_level "${level}")"
    reset="\033[0m"
    if [[ -t 2 ]]; then
      printf '%b[%s] %s (pipeline=%s task=%s step=%s host=%s)%b\n' "${color}" "${level}" "${msg}" "${pipeline_name}" "${task_id}" "${step_name}" "${host}" "${reset}" 1>&2
    else
      printf '[%s] %s (pipeline=%s task=%s step=%s host=%s)\n' "${level}" "${msg}" "${pipeline_name}" "${task_id}" "${step_name}" "${host}" 1>&2
    fi
  fi

  # 写入日志文件
  if [[ -n "${KUBEXM_LOG_FILE}" ]]; then
    echo "${timestamp} [${level}] ${msg} (pipeline=${pipeline_name} task=${task_id} step=${step_name} host=${host})" >> "${KUBEXM_LOG_FILE}"
  fi
}

logger::debug() {
  if [[ ${KUBEXM_LOG_LEVEL:-1} -le ${LOG_LEVEL_DEBUG} ]]; then
    logger::_emit "DEBUG" "$*"
  fi
}

logger::info() {
  if [[ ${KUBEXM_LOG_LEVEL:-1} -le ${LOG_LEVEL_INFO} ]]; then
    logger::_emit "INFO" "$*"
  fi
}

logger::warn() {
  if [[ ${KUBEXM_LOG_LEVEL:-1} -le ${LOG_LEVEL_WARN} ]]; then
    logger::_emit "WARN" "$*"
  fi
}

logger::error() {
  if [[ ${KUBEXM_LOG_LEVEL:-1} -le ${LOG_LEVEL_ERROR} ]]; then
    logger::_emit "ERROR" "$*"
  fi
}

logger::success() {
  if [[ ${KUBEXM_LOG_LEVEL:-1} -le ${LOG_LEVEL_INFO} ]]; then
    logger::_emit "SUCCESS" "$*"
  fi
}

# 导出函数
export -f logger::debug
export -f logger::info
export -f logger::warn
export -f logger::error
export -f logger::success
