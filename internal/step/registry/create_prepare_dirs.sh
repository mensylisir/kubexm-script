#!/usr/bin/env bash
set -euo pipefail

step::registry.create.prepare.dirs::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local registry_config_dir registry_data_dir
  registry_config_dir="$(context::get "registry_create_config_dir" || true)"
  registry_data_dir="$(context::get "registry_create_data_dir" || true)"
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "${registry_config_dir}" && \
     step::check::remote_dir_exists "${KUBEXM_HOST}" "${registry_data_dir}"; then
    return 0
  fi
  return 1
}

step::registry.create.prepare.dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local registry_config_dir registry_data_dir
  registry_config_dir="$(context::get "registry_create_config_dir" || true)"
  registry_data_dir="$(context::get "registry_create_data_dir" || true)"

  runner::remote_exec "mkdir -p ${registry_config_dir} ${registry_data_dir}"
}

step::registry.create.prepare.dirs::rollback() { return 0; }

step::registry.create.prepare.dirs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
