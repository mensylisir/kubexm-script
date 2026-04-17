#!/usr/bin/env bash
set -euo pipefail

step::images.push.packages.concurrent.prepare::check() { return 1; }

step::images.push.packages.concurrent.prepare::run() {
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

  if ! command -v skopeo &>/dev/null; then
    log::error "Skopeo未安装"
    return 1
  fi

  local log_dir
  log_dir="/tmp/kubexm-push-$$"
  mkdir -p "$log_dir"

  context::set "images_push_concurrent_log_dir" "${log_dir}"
}

step::images.push.packages.concurrent.prepare::rollback() { return 0; }

step::images.push.packages.concurrent.prepare::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
