#!/usr/bin/env bash
set -euo pipefail

step::download.generate.manifest::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "package_manifest" && return 0
  return 1
}

step::download.generate.manifest::run() {
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

  local images_list="${DOWNLOAD_DIR}/images/images.list"
  if [[ -f "${images_list}" ]]; then
    sort -u "${images_list}" -o "${images_list}"
    log::info "Images list updated: ${images_list}"
  fi

  log::info "Generating package manifest..."
  download::generate_package_manifest "${DOWNLOAD_DIR}" "${cluster_name}"
  checkpoint::save "package_manifest"
}

step::download.generate.manifest::rollback() { return 0; }

step::download.generate.manifest::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
