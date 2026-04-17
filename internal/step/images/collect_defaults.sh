#!/usr/bin/env bash
set -euo pipefail

step::images.push.collect.defaults::check() { return 1; }

step::images.push.collect.defaults::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local image_list_file
  image_list_file="${KUBEXM_ROOT}/etc/kubexm/images.txt"

  context::set "images_push_help" "false"
  context::set "images_push_cluster_name" ""
  context::set "images_push_image_list_file" "${image_list_file}"
  context::set "images_push_enable_dual" "false"
  context::set "images_push_enable_manifest" "false"
  context::set "images_push_target_registry" "localhost:5000"
  context::set "images_push_from_packages" "false"
  context::set "images_push_packages_dir" ""
  context::set "images_push_max_parallel" "5"
  context::set "images_push_enable_concurrent" "false"
}

step::images.push.collect.defaults::rollback() { return 0; }

step::images.push.collect.defaults::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
