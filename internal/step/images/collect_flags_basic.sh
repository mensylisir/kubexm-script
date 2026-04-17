#!/usr/bin/env bash
set -euo pipefail

step::images.push.collect.flags.basic::check() { return 1; }

step::images.push.collect.flags.basic::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local cluster_name image_list_file enable_dual enable_manifest
  local target_registry show_help

  cluster_name="$(context::get "images_push_cluster_name" || true)"
  image_list_file="$(context::get "images_push_image_list_file" || true)"
  enable_dual="$(context::get "images_push_enable_dual" || echo "false")"
  enable_manifest="$(context::get "images_push_enable_manifest" || echo "false")"
  target_registry="$(context::get "images_push_target_registry" || true)"
  show_help="$(context::get "images_push_help" || echo "false")"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cluster=*)
        cluster_name="${1#*=}"
        ;;
      --list=*)
        image_list_file="${1#*=}"
        ;;
      --dual)
        enable_dual="true"
        ;;
      --manifest)
        enable_manifest="true"
        ;;
      --target-registry=*)
        target_registry="${1#*=}"
        ;;
      -h|--help)
        log::info "Usage: kubexm push images [options]"
        show_help="true"
        break
        ;;
      *)
        ;;
    esac
    shift
  done

  context::set "images_push_help" "${show_help}"
  context::set "images_push_cluster_name" "${cluster_name}"
  context::set "images_push_image_list_file" "${image_list_file}"
  context::set "images_push_enable_dual" "${enable_dual}"
  context::set "images_push_enable_manifest" "${enable_manifest}"
  context::set "images_push_target_registry" "${target_registry}"
}

step::images.push.collect.flags.basic::rollback() { return 0; }

step::images.push.collect.flags.basic::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
