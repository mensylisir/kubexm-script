#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Progress Tracking
# ==============================================================================
# 提供执行进度跟踪功能
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 进度状态
PROGRESS_STATE_PENDING="pending"
PROGRESS_STATE_RUNNING="running"
PROGRESS_STATE_COMPLETED="completed"
PROGRESS_STATE_FAILED="failed"
PROGRESS_STATE_SKIPPED="skipped"

# 内部变量
_PROGRESS_START_TIME=""
_PROGRESS_TOTAL_STEPS=0
_PROGRESS_COMPLETED_STEPS=0
_PROGRESS_FAILED_STEPS=0
_PROGRESS_SKIPPED_STEPS=0
_PROGRESS_CURRENT_STEP=""
_PROGRESS_STEP_START_TIME=""

#######################################
# 初始化进度跟踪器
# 用法: progress::init <total_steps>
#######################################
progress::init() {
  local total_steps="${1:-0}"
  _PROGRESS_START_TIME=$(date +%s)
  _PROGRESS_TOTAL_STEPS=${total_steps}
  _PROGRESS_COMPLETED_STEPS=0
  _PROGRESS_FAILED_STEPS=0
  _PROGRESS_SKIPPED_STEPS=0
  _PROGRESS_CURRENT_STEP=""

  log::info "Progress tracking initialized: ${total_steps} total steps"
}

#######################################
# 开始执行步骤
# 用法: progress::step_start <step_name>
#######################################
progress::step_start() {
  local step_name="$1"
  _PROGRESS_CURRENT_STEP="${step_name}"
  _PROGRESS_STEP_START_TIME=$(date +%s)

  log::debug "Step started: ${step_name}"
}

#######################################
# 步骤完成
# 用法: progress::step_complete <step_name>
#######################################
progress::step_complete() {
  local step_name="$1"
  local duration=0

  if [[ -n "${_PROGRESS_STEP_START_TIME}" ]]; then
    local end_time
    end_time=$(date +%s)
    duration=$((end_time - _PROGRESS_STEP_START_TIME))
  fi

  ((_PROGRESS_COMPLETED_STEPS++)) || true
  _PROGRESS_CURRENT_STEP=""
  _PROGRESS_STEP_START_TIME=""

  # 计算进度百分比
  local percent=0
  if [[ ${_PROGRESS_TOTAL_STEPS} -gt 0 ]]; then
    percent=$((_PROGRESS_COMPLETED_STEPS * 100 / _PROGRESS_TOTAL_STEPS))
  fi

  log::debug "Step completed: ${step_name} (${duration}s) [${percent}%]"
}

#######################################
# 步骤失败
# 用法: progress::step_failed <step_name>
#######################################
progress::step_failed() {
  local step_name="$1"
  local duration=0

  if [[ -n "${_PROGRESS_STEP_START_TIME}" ]]; then
    local end_time
    end_time=$(date +%s)
    duration=$((end_time - _PROGRESS_STEP_START_TIME))
  fi

  ((_PROGRESS_FAILED_STEPS++)) || true
  _PROGRESS_CURRENT_STEP=""
  _PROGRESS_STEP_START_TIME=""

  log::error "Step failed: ${step_name} (${duration}s)"

  # 计算进度百分比
  local percent=0
  if [[ ${_PROGRESS_TOTAL_STEPS} -gt 0 ]]; then
    percent=$(((_PROGRESS_COMPLETED_STEPS + _PROGRESS_FAILED_STEPS) * 100 / _PROGRESS_TOTAL_STEPS))
  fi

  echo "Progress: ${percent}% | Completed: ${_PROGRESS_COMPLETED_STEPS} | Failed: ${_PROGRESS_FAILED_STEPS} | Skipped: ${_PROGRESS_SKIPPED_STEPS}" >&2
}

#######################################
# 步骤跳过（幂等）
# 用法: progress::step_skipped <step_name>
#######################################
progress::step_skipped() {
  local step_name="$1"
  ((_PROGRESS_SKIPPED_STEPS++)) || true

  log::debug "Step skipped (already satisfied): ${step_name}"

  # 计算进度百分比
  local percent=0
  if [[ ${_PROGRESS_TOTAL_STEPS} -gt 0 ]]; then
    percent=$(((_PROGRESS_COMPLETED_STEPS + _PROGRESS_SKIPPED_STEPS) * 100 / _PROGRESS_TOTAL_STEPS))
  fi

  # 只在完整百分比变化时输出
  if [[ $((percent % 10)) -eq 0 ]]; then
    echo "Progress: ${percent}% | Completed: ${_PROGRESS_COMPLETED_STEPS} | Skipped: ${_PROGRESS_SKIPPED_STEPS}" >&2
  fi
}

#######################################
# 获取进度摘要
# 用法: progress::summary
#######################################
progress::summary() {
  local total_time=0

  if [[ -n "${_PROGRESS_START_TIME}" ]]; then
    local end_time
    end_time=$(date +%s)
    total_time=$((end_time - _PROGRESS_START_TIME))
  fi

  local percent=0
  if [[ ${_PROGRESS_TOTAL_STEPS} -gt 0 ]]; then
    percent=$(((_PROGRESS_COMPLETED_STEPS + _PROGRESS_SKIPPED_STEPS) * 100 / _PROGRESS_TOTAL_STEPS))
  fi

  echo ""
  echo "=== Execution Summary ==="
  echo "Total steps: ${_PROGRESS_TOTAL_STEPS}"
  echo "Completed:   ${_PROGRESS_COMPLETED_STEPS}"
  echo "Failed:      ${_PROGRESS_FAILED_STEPS}"
  echo "Skipped:     ${_PROGRESS_SKIPPED_STEPS}"
  echo "Duration:    ${total_time}s"
  echo "Progress:    ${percent}%"
  echo "========================"
}

#######################################
# 获取当前状态（用于API/JSON输出）
# 用法: progress::status
# 输出: JSON格式状态
#######################################
progress::status() {
  local percent=0
  if [[ ${_PROGRESS_TOTAL_STEPS} -gt 0 ]]; then
    percent=$(((_PROGRESS_COMPLETED_STEPS + _PROGRESS_SKIPPED_STEPS) * 100 / _PROGRESS_TOTAL_STEPS))
  fi

  if [[ "${KUBEXM_LOG_FORMAT}" == "json" ]]; then
    cat <<EOF
{
  "total": ${_PROGRESS_TOTAL_STEPS},
  "completed": ${_PROGRESS_COMPLETED_STEPS},
  "failed": ${_PROGRESS_FAILED_STEPS},
  "skipped": ${_PROGRESS_SKIPPED_STEPS},
  "percent": ${percent},
  "current_step": "${_PROGRESS_CURRENT_STEP}"
}
EOF
  else
    echo "Progress: ${percent}% | Completed: ${_PROGRESS_COMPLETED_STEPS} | Failed: ${_PROGRESS_FAILED_STEPS} | Skipped: ${_PROGRESS_SKIPPED_STEPS} | Current: ${_PROGRESS_CURRENT_STEP}"
  fi
}

# 导出函数
export -f progress::init
export -f progress::step_start
export -f progress::step_complete
export -f progress::step_failed
export -f progress::step_skipped
export -f progress::summary
export -f progress::status