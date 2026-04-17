#!/usr/bin/env bash
set -euo pipefail

step::registry.create.copy.config::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local registry_config_dir
  registry_config_dir="$(context::get "registry_create_config_dir" || true)"
  if step::check::remote_file_exists "${KUBEXM_HOST}" "${registry_config_dir}/config.yml"; then
    return 0
  fi
  return 1
}

step::registry.create.copy.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local cfg_file registry_config_dir
  cfg_file="$(context::get "registry_create_cfg_file" || true)"
  registry_config_dir="$(context::get "registry_create_config_dir" || true)"
  runner::remote_copy_file "${cfg_file}" "${registry_config_dir}/config.yml"
}

step::registry.create.copy.config::rollback() { return 0; }

step::registry.create.copy.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
