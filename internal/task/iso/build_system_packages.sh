#!/usr/bin/env bash
set -euo pipefail

step::iso.build.system.packages::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local build_iso_params=""
  if [[ "${KUBEXM_BUILD_ALL:-false}" == "true" ]]; then
    build_iso_params="$(defaults::get_build_os_list)"
  elif [[ -n "${KUBEXM_BUILD_OS:-}${KUBEXM_BUILD_OS_VERSION:-}" ]]; then
    build_iso_params="${KUBEXM_BUILD_OS:-${KUBEXM_BUILD_OS_VERSION}}"
  fi

  if [[ -z "${build_iso_params}" ]]; then
    return 0
  fi

  # Check per-OS ISO exists
  local output_base="${KUBEXM_ROOT}/packages/iso"
  local first_arch
  first_arch="$(echo "${KUBEXM_BUILD_ARCH:-$(defaults::get_arch_list)}" | cut -d',' -f1)"
  local first_os
  first_os="${build_iso_params%%,*}"

  local sample_iso="${output_base}/${first_os}"/*/"${first_arch}"/*.iso
  [[ -f "${sample_iso}" ]]
}

step::iso.build.system.packages::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/resources/system_iso.sh"

  local build_iso_params=""
  if [[ "${KUBEXM_BUILD_ALL:-false}" == "true" ]]; then
    build_iso_params="$(defaults::get_build_os_list)"
  elif [[ -n "${KUBEXM_BUILD_OS:-}${KUBEXM_BUILD_OS_VERSION:-}" ]]; then
    build_iso_params="${KUBEXM_BUILD_OS:-${KUBEXM_BUILD_OS_VERSION}}"
  fi

  if [[ -z "${build_iso_params}" ]]; then
    return 0
  fi

  local output_base="${KUBEXM_ROOT}/packages/iso"
  mkdir -p "${output_base}"

  # Use checkpoint dir from deps.resolve step if available
  local pkg_checkpoint_dir="${KUBEXM_ISO_CHECKPOINT_DIR:-${KUBEXM_ROOT}/.kubexm-checkpoint/iso}"

  local first_arch
  first_arch="$(echo "${KUBEXM_BUILD_ARCH:-$(defaults::get_arch_list)}" | cut -d',' -f1)"

  # Use per-OS build: generates ${output_base}/${os_name}/${os_version}/${arch}/${os_name}-${os_version}-${arch}.iso
  # Pass checkpoint dir so build uses pre-resolved package lists
  system_iso::build_per_os "${output_base}" "${build_iso_params}" "${first_arch}" \
    "${KUBEXM_BUILD_LOCAL:-false}" "${pkg_checkpoint_dir}"
}

step::iso.build.system.packages::rollback() { return 0; }

step::iso.build.system.packages::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
