#!/usr/bin/env bash
set -euo pipefail

step::images.push.packages.concurrent.gate::check() { return 1; }

step::images.push.packages.concurrent.gate::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local push_from_packages enable_concurrent
  push_from_packages="$(context::get "images_push_from_packages" || true)"
  enable_concurrent="$(context::get "images_push_enable_concurrent" || echo "false")"
  if [[ "${push_from_packages}" != "true" || "${enable_concurrent}" != "true" ]]; then
    context::set "images_push_concurrent_skip" "true"
    return 0
  fi

  context::set "images_push_concurrent_skip" "false"

  local target_registry max_parallel
  target_registry="$(context::get "images_push_target_registry" || true)"
  max_parallel="$(context::get "images_push_max_parallel" || echo "5")"

  log::info "目标Registry: $target_registry"
  log::info "使用并发推送模式（并发数: $max_parallel）"
}

step::images.push.packages.concurrent.gate::rollback() { return 0; }

step::images.push.packages.concurrent.gate::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
