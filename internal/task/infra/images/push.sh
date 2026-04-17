#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Images Task - Push Operations
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# 镜像推送收集任务
task::images_push_collect() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "images.push.collect.defaults:${KUBEXM_ROOT}/internal/step/images/collect_defaults.sh" \
    "images.push.collect.flags.basic:${KUBEXM_ROOT}/internal/step/images/collect_flags_basic.sh" \
    "images.push.collect.flags.packages:${KUBEXM_ROOT}/internal/step/images/collect_flags_packages.sh" \
    "images.push.collect.flags.unknown:${KUBEXM_ROOT}/internal/step/images/collect_flags_unknown.sh" \
    "images.push.collect.validate:${KUBEXM_ROOT}/internal/step/images/collect_validate.sh" \
    "images.push.collect.config:${KUBEXM_ROOT}/internal/step/images/collect_config.sh" \
    "images.push.collect.packages.list:${KUBEXM_ROOT}/internal/step/images/collect_packages_list.sh"
}

# 镜像推送执行任务 (并发)
task::images_push_packages_concurrent() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "images.push.packages.concurrent.gate:${KUBEXM_ROOT}/internal/step/images/packages_concurrent_gate.sh" \
    "images.push.packages.concurrent.prepare:${KUBEXM_ROOT}/internal/step/images/packages_concurrent_prepare.sh" \
    "images.push.packages.concurrent.exec:${KUBEXM_ROOT}/internal/step/images/packages_concurrent_exec.sh" \
    "images.push.packages.concurrent.summary:${KUBEXM_ROOT}/internal/step/images/packages_concurrent_summary.sh"
}

# 镜像推送执行任务 (串行)
task::images_push_packages_sequential() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "images.push.packages.sequential:${KUBEXM_ROOT}/internal/step/images/packages_sequential.sh"
}

# 镜像推送汇总和清单任务
task::images_push_packages_summary() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "images.push.packages.summary:${KUBEXM_ROOT}/internal/step/images/packages_summary.sh"
}

task::images_push_packages_manifest() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "images.push.packages.manifest:${KUBEXM_ROOT}/internal/step/images/packages_manifest.sh"
}

task::images_push_from_list() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "images.push.from.list:${KUBEXM_ROOT}/internal/step/images/from_list.sh"
}

export -f task::images_push_collect
export -f task::images_push_packages_concurrent
export -f task::images_push_packages_sequential
export -f task::images_push_packages_summary
export -f task::images_push_packages_manifest
export -f task::images_push_from_list