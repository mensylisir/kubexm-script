#!/usr/bin/env bash
set -euo pipefail

step::images.push.collect.flags.packages::check() { return 1; }

step::images.push.collect.flags.packages::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local push_from_packages packages_dir max_parallel enable_concurrent
  push_from_packages="$(context::get "images_push_from_packages" || echo "false")"
  packages_dir="$(context::get "images_push_packages_dir" || true)"
  max_parallel="$(context::get "images_push_max_parallel" || echo "5")"
  enable_concurrent="$(context::get "images_push_enable_concurrent" || echo "false")"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --packages)
        push_from_packages="true"
        packages_dir="${KUBEXM_ROOT}/packages/images"
        ;;
      --packages-dir=*)
        push_from_packages="true"
        packages_dir="${1#*=}"
        ;;
      --parallel=*)
        max_parallel="${1#*=}"
        enable_concurrent="true"
        log::info "启用并发模式，并发数: $max_parallel"
        ;;
      *)
        ;;
    esac
    shift
  done

  context::set "images_push_from_packages" "${push_from_packages}"
  context::set "images_push_packages_dir" "${packages_dir}"
  context::set "images_push_max_parallel" "${max_parallel}"
  context::set "images_push_enable_concurrent" "${enable_concurrent}"
}

step::images.push.collect.flags.packages::rollback() { return 0; }

step::images.push.collect.flags.packages::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
