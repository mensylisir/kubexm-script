#!/usr/bin/env bash
set -euo pipefail

step::registry.create.collect.settings::check() { return 1; }

step::registry.create.collect.settings::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local arch
  arch="$(context::get "registry_create_arch" || true)"

  local registry_version registry_port registry_data_dir registry_config_dir
  registry_version=$(config::get "spec.registry.version" "$(defaults::get_registry_version)")
  registry_port=$(config::get_registry_port)
  registry_data_dir=$(config::get_registry_data_dir)
  registry_config_dir=$(config::get "spec.registry.config_dir" "/etc/registry")

  local bin_src="${KUBEXM_ROOT}/packages/registry/${registry_version}/${arch}/registry"
  if [[ ! -f "${bin_src}" ]]; then
    log::error "Registry binary not found: ${bin_src}"
    return 1
  fi

  context::set "registry_create_version" "${registry_version}"
  context::set "registry_create_port" "${registry_port}"
  context::set "registry_create_data_dir" "${registry_data_dir}"
  context::set "registry_create_config_dir" "${registry_config_dir}"
  context::set "registry_create_bin_src" "${bin_src}"
}

step::registry.create.collect.settings::rollback() { return 0; }

step::registry.create.collect.settings::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
