#!/usr/bin/env bash
set -euo pipefail

step::images.push.collect.validate::check() { return 1; }

step::images.push.collect.validate::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local show_help
  show_help="$(context::get "images_push_help" || true)"
  if [[ "${show_help}" == "true" ]]; then
    return 0
  fi
}

step::images.push.collect.validate::rollback() { return 0; }

step::images.push.collect.validate::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
