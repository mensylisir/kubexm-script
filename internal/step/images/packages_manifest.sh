#!/usr/bin/env bash
set -euo pipefail

step::images.push.packages.manifest::check() { return 1; }

step::images.push.packages.manifest::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/utils/image_push.sh"

  local push_from_packages
  push_from_packages="$(context::get "images_push_from_packages" || true)"
  if [[ "${push_from_packages}" != "true" ]]; then
    return 0
  fi

  local enable_manifest
  enable_manifest="$(context::get "images_push_enable_manifest" || echo "false")"
  if [[ "${enable_manifest}" != "true" ]]; then
    return 0
  fi

  local success_count
  success_count="$(context::get "images_push_packages_success" || echo "0")"
  if [[ "${success_count}" == "0" ]]; then
    return 0
  fi

  log::info "生成manifest..."

  local target_registry items
  target_registry="$(context::get "images_push_target_registry" || true)"
  items="$(context::get "images_push_packages_items" || true)"

  local manifest_images=""
  while IFS= read -r item; do
    if [[ -z "$item" ]]; then
      continue
    fi
    local image
    image="${item%%|*}"
    local image_path
    image_path="$(image_push::strip_registry "$image")"
    manifest_images+="${target_registry}/${image_path}"$'\n'
  done <<< "$items"

  if [[ -n "$manifest_images" ]]; then
    local manifest_name="${target_registry}/kubexm/manifests/latest"
    if image_push::manifest_create "$manifest_name" "$manifest_images" "$manifest_name"; then
      log::success "Manifest创建成功: $manifest_name"
    else
      log::warn "Manifest创建失败"
    fi
  fi
}

step::images.push.packages.manifest::rollback() { return 0; }

step::images.push.packages.manifest::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
