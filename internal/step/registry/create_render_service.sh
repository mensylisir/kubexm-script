#!/usr/bin/env bash
set -euo pipefail

step::registry.create.render.service::check() { return 1; }

step::registry.create.render.service::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local registry_data_dir
  registry_data_dir="$(context::get "registry_create_data_dir" || true)"

  local tmp_dir svc_file
  tmp_dir="$(context::get "registry_create_tmp_dir" || true)"
  if [[ -z "${tmp_dir}" ]]; then
    tmp_dir="$(mktemp -d)"
    context::set "registry_create_tmp_dir" "${tmp_dir}"
  fi
  svc_file="${tmp_dir}/registry.service"

  template::render_with_vars \
    "${KUBEXM_ROOT}/templates/registry/registry.service.tmpl" \
    "${svc_file}" \
    "REGISTRY_DATA_DIR=${registry_data_dir}"

  context::set "registry_create_svc_file" "${svc_file}"
}

step::registry.create.render.service::rollback() { return 0; }

step::registry.create.render.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
