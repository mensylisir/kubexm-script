#!/usr/bin/env bash
set -euo pipefail

step::registry.create.copy.service::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/systemd/system/registry.service"; then
    return 0
  fi
  return 1
}

step::registry.create.copy.service::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local svc_file
  svc_file="$(context::get "registry_create_svc_file" || true)"
  runner::remote_copy_file "${svc_file}" "/etc/systemd/system/registry.service"
}

step::registry.create.copy.service::rollback() { return 0; }

step::registry.create.copy.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
