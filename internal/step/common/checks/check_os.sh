#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: check.os
# 操作系统兼容性检查（预留占位）
# 注意：此 step 目前为 no-op placeholder。OS 兼容性检查应在
# pipeline 加载配置阶段完成，而非作为独立 step 重复执行。
# check: 永远返回 0（跳过），由上层 pipeline 确保 OS 兼容性
# run:   无操作
# ==============================================================================

step::check.os::check() {
  # OS 检查在 pipeline 加载配置时已完成，此处 no-op 跳过
  return 0
}

step::check.os::run() {
  # 无操作
  return 0
}

step::check.os::rollback() { return 0; }

step::check.os::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
