#!/usr/bin/env bash
set -euo pipefail

step::images.push.packages.concurrent.summary::check() { return 1; }

step::images.push.packages.concurrent.summary::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local skip
  skip="$(context::get "images_push_concurrent_skip" || echo "false")"
  if [[ "${skip}" == "true" ]]; then
    return 0
  fi

  local log_dir
  log_dir="$(context::get "images_push_concurrent_log_dir" || true)"

  local success_count=0
  local fail_count=0
  if [[ -f "$log_dir/results.txt" ]]; then
    success_count=$(grep -c "^SUCCESS:" "$log_dir/results.txt" 2>/dev/null || true)
    fail_count=$(grep -c "^FAILED:" "$log_dir/results.txt" 2>/dev/null || true)
  fi

  if [[ $fail_count -gt 0 ]]; then
    log::error "以下镜像推送失败:"
    grep "^FAILED:" "$log_dir/results.txt" | cut -d: -f2- | while read -r image; do
      log::error "  - $image"
    done
  fi

  rm -rf "$log_dir"
  log::info "推送完成 - 成功: $success_count, 失败: $fail_count"

  context::set "images_push_packages_success" "${success_count}"
  context::set "images_push_packages_fail" "${fail_count}"
}

step::images.push.packages.concurrent.summary::rollback() { return 0; }

step::images.push.packages.concurrent.summary::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
