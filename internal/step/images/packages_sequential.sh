#!/usr/bin/env bash
set -euo pipefail

step::images.push.packages.sequential::check() { return 1; }

step::images.push.packages.sequential::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/utils/utils.sh"
  source "${KUBEXM_ROOT}/internal/utils/image_push.sh"

  local push_from_packages enable_concurrent
  push_from_packages="$(context::get "images_push_from_packages" || true)"
  enable_concurrent="$(context::get "images_push_enable_concurrent" || echo "false")"
  if [[ "${push_from_packages}" != "true" || "${enable_concurrent}" == "true" ]]; then
    return 0
  fi

  local target_registry items total_images
  target_registry="$(context::get "images_push_target_registry" || true)"
  items="$(context::get "images_push_packages_items" || true)"
  total_images="$(context::get "images_push_packages_total" || echo "0")"

  log::info "目标Registry: $target_registry"

  local success_count=0
  local fail_count=0
  local current=0
  local item
  while IFS= read -r item; do
    if [[ -z "$item" ]]; then
      continue
    fi

    ((current++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    create_progress_bar "$current" "$total_images"

    local image image_dir image_path
    image="${item%%|*}"
    image_dir="${item#*|}"
    image_path="$(image_push::strip_registry "$image")"

    if image_push::load_from_oci "$image_dir" "$target_registry/$image_path"; then
      ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  done <<< "$items"

  echo
  log::info "推送完成 - 成功: $success_count, 失败: $fail_count"

  context::set "images_push_packages_success" "${success_count}"
  context::set "images_push_packages_fail" "${fail_count}"
}

step::images.push.packages.sequential::rollback() { return 0; }

step::images.push.packages.sequential::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
