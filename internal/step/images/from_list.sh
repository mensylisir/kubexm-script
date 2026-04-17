#!/usr/bin/env bash
set -euo pipefail

step::images.push.from.list::check() { return 1; }

step::images.push.from.list::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/image_push.sh"

  local push_from_packages
  push_from_packages="$(context::get "images_push_from_packages" || true)"
  if [[ "${push_from_packages}" == "true" ]]; then
    return 0
  fi

  local image_list_file target_registry enable_dual enable_manifest
  image_list_file="$(context::get "images_push_image_list_file" || true)"
  target_registry="$(context::get "images_push_target_registry" || true)"
  enable_dual="$(context::get "images_push_enable_dual" || echo "false")"
  enable_manifest="$(context::get "images_push_enable_manifest" || echo "false")"

  if ! image_push::push_from_list "$image_list_file" "$target_registry" "$enable_dual" "$enable_manifest"; then
    return 1
  fi
}

step::images.push.from.list::rollback() { return 0; }

step::images.push.from.list::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
