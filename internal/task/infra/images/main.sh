#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Images Task - Main
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/infra/images/push.sh"

# 完整镜像推送流程
task::push_images() {
  local ctx="$1"
  shift

  # 收集镜像信息
  task::images_push_collect "${ctx}" "$@"

  # 并发推送
  task::images_push_packages_concurrent "${ctx}" "$@"

  # 串行推送
  task::images_push_packages_sequential "${ctx}" "$@"

  # 推送清单
  task::images_push_packages_manifest "${ctx}" "$@"

  # 汇总
  task::images_push_packages_summary "${ctx}" "$@"

  # 从列表推送
  task::images_push_from_list "${ctx}" "$@"
}

export -f task::push_images