#!/usr/bin/env bash
set -euo pipefail

step::download.build.system.iso::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  local build_iso_params=""
  if [[ "${DOWNLOAD_BUILD_ALL}" == "true" ]]; then
    build_iso_params="$(defaults::get_build_os_list)"
  elif [[ -n "${DOWNLOAD_BUILD_OS:-}${DOWNLOAD_BUILD_OS_VERSION:-}" ]]; then
    build_iso_params="${DOWNLOAD_BUILD_OS:-${DOWNLOAD_BUILD_OS_VERSION}}"
  fi

  if [[ -z "${build_iso_params}" ]]; then
    return 0
  fi

  checkpoint::is_done "system_iso" && return 0
  return 1
}

step::download.build.system.iso::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  download::init_context

  local build_iso_params=""
  if [[ "${DOWNLOAD_BUILD_ALL}" == "true" ]]; then
    build_iso_params="$(defaults::get_build_os_list)"
  elif [[ -n "${DOWNLOAD_BUILD_OS:-}${DOWNLOAD_BUILD_OS_VERSION:-}" ]]; then
    build_iso_params="${DOWNLOAD_BUILD_OS:-${DOWNLOAD_BUILD_OS_VERSION}}"
  fi

  if [[ -z "${build_iso_params}" ]]; then
    log::info "Skipping system packages ISO build (use --with-build-os to enable)"
    return 0
  fi

  log::info "Building system packages ISO for: ${build_iso_params}"
  local first_arch
  first_arch="$(echo "${DOWNLOAD_ARCH_LIST}" | awk '{print $1}')"
  local system_iso_output="${DOWNLOAD_DIR}/system-packages.iso"

  if system_iso::build "${system_iso_output}" "${build_iso_params}" "${first_arch}" "${DOWNLOAD_BUILD_LOCAL:-false}"; then
    log::success "System packages ISO built successfully"
    checkpoint::save "system_iso"
  else
    log::warn "System packages ISO build failed, continuing..."
  fi
}

step::download.build.system.iso::rollback() { return 0; }

step::download.build.system.iso::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
