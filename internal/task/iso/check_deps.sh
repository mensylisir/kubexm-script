#!/usr/bin/env bash
set -euo pipefail

step::iso.check.deps::check() {
  [[ "${KUBEXM_ISO_CHECK_DEPS_DONE:-false}" == "true" ]]
}

step::iso.check.deps::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/resources/system_iso.sh"
  source "${KUBEXM_ROOT}/internal/utils/resources/build_docker.sh"

  local build_iso_params=""
  if [[ "${KUBEXM_BUILD_ALL:-false}" == "true" ]]; then
    build_iso_params="$(defaults::get_build_os_list)"
  elif [[ -n "${KUBEXM_BUILD_OS:-}${KUBEXM_BUILD_OS_VERSION:-}" ]]; then
    build_iso_params="${KUBEXM_BUILD_OS:-${KUBEXM_BUILD_OS_VERSION}}"
  fi

  if [[ -z "${build_iso_params}" ]]; then
    KUBEXM_ISO_CHECK_DEPS_DONE="true"
    return 0
  fi

  local iso_tool=""
  for tool in mkisofs genisoimage xorriso; do
    if command -v "${tool}" &>/dev/null; then
      iso_tool="${tool}"
      break
    fi
  done

  if [[ -z "${iso_tool}" ]]; then
    echo "missing ISO build tool (mkisofs/genisoimage/xorriso)" >&2
    return 1
  fi

  if [[ "${KUBEXM_BUILD_LOCAL:-false}" != "true" ]]; then
    build::check_docker || return 1
  fi

  KUBEXM_ISO_CHECK_DEPS_DONE="true"
}

step::iso.check.deps::rollback() { return 0; }

step::iso.check.deps::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
