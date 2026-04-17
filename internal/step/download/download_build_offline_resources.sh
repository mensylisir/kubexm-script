#!/usr/bin/env bash
set -euo pipefail

step::download.build.offline.resources::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  local offline_enabled="false"
  if config::get_offline_enabled 2>/dev/null | grep -q "true"; then
    offline_enabled="true"
  fi

  if [[ "${offline_enabled}" != "true" ]]; then
    return 0
  fi

  checkpoint::is_done "offline_resources" && return 0
  return 1
}

step::download.build.offline.resources::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for download" >&2
    return 2
  fi

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  local offline_enabled="false"
  if config::get_offline_enabled 2>/dev/null | grep -q "true"; then
    offline_enabled="true"
  fi

  if [[ "${offline_enabled}" != "true" ]]; then
    return 0
  fi

  log::info "Offline build enabled, building offline resources..."
  download::build_offline_resources "${DOWNLOAD_DIR}" "${cluster_name}"
  checkpoint::save "offline_resources"
}

step::download.build.offline.resources::rollback() { return 0; }

step::download.build.offline.resources::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
