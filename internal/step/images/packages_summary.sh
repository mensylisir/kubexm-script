#!/usr/bin/env bash
set -euo pipefail

step::images.push.packages.summary::check() { return 1; }

step::images.push.packages.summary::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local push_from_packages
  push_from_packages="$(context::get "images_push_from_packages" || true)"
  if [[ "${push_from_packages}" != "true" ]]; then
    return 0
  fi

  local fail_count
  fail_count="$(context::get "images_push_packages_fail" || echo "0")"
  if [[ "${fail_count}" == "0" ]]; then
    log::success "所有镜像推送成功"
    return 0
  fi

  log::error "${fail_count} 个镜像推送失败"
  return 1
}

step::images.push.packages.summary::rollback() { return 0; }

step::images.push.packages.summary::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
