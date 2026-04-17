#!/usr/bin/env bash
set -euo pipefail

step::registry.delete::check() {
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  if runner::remote_exec "systemctl is-enabled --quiet registry" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

step::registry.delete::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local force="false"
  local delete_images="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*) cluster_name="${arg#*=}" ;;
      --force) force="true" ;;
      --delete-images) delete_images="true" ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for delete registry" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local registry_data_dir registry_config_dir
  registry_data_dir=$(config::get_registry_data_dir)
  registry_config_dir=$(config::get "spec.registry.config_dir" "/etc/registry")

  runner::remote_exec "systemctl stop registry >/dev/null 2>&1 || true"
  runner::remote_exec "systemctl disable registry >/dev/null 2>&1 || true"
  runner::remote_exec "rm -f /etc/systemd/system/registry.service"
  runner::remote_exec "systemctl daemon-reload"
  runner::remote_exec "rm -rf ${registry_config_dir}"

  if [[ "${delete_images}" == "true" ]]; then
    if [[ "${force}" != "true" ]]; then
      log::warn "Use --force to delete registry data: ${registry_data_dir}"
      return 1
    fi
    runner::remote_exec "rm -rf ${registry_data_dir}"
  fi

  log::info "Registry removed on ${KUBEXM_HOST}"
}

step::registry.delete::rollback() { return 0; }

step::registry.delete::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
