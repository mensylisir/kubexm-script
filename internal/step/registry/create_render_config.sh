#!/usr/bin/env bash
set -euo pipefail

step::registry.create.render.config::check() { return 1; }

step::registry.create.render.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local registry_data_dir registry_port
  registry_data_dir="$(context::get "registry_create_data_dir" || true)"
  registry_port="$(context::get "registry_create_port" || true)"

  local tmp_dir cfg_file
  tmp_dir="$(mktemp -d)"
  cfg_file="${tmp_dir}/config.yml"

  template::render_with_vars \
    "${KUBEXM_ROOT}/templates/registry/config.yml.tmpl" \
    "${cfg_file}" \
    "REGISTRY_DATA_DIR=${registry_data_dir}" \
    "REGISTRY_PORT=${registry_port}"

  context::set "registry_create_tmp_dir" "${tmp_dir}"
  context::set "registry_create_cfg_file" "${cfg_file}"
}

step::registry.create.render.config::rollback() { return 0; }

step::registry.create.render.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
