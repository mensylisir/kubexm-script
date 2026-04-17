#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ISO Build Task - Main
# ==============================================================================

source "${KUBEXM_ROOT}/internal/step/lib/registry.sh"
source "${KUBEXM_ROOT}/internal/step/lib/step_runner.sh"
source "${KUBEXM_ROOT}/internal/config/defaults.sh"

_task::iso_parse_args() {
  local build_all="false"
  local build_os=""
  local build_os_version=""
  local build_arch=""
  local build_local="false"

  local arg
  for arg in "$@"; do
    case "${arg}" in
      --with-build-all)
        build_all="true"
        ;;
      --with-build-os=*)
        build_os="${arg#*=}"
        ;;
      --with-build-os-version=*)
        build_os_version="${arg#*=}"
        ;;
      --with-build-arch=*)
        build_arch="${arg#*=}"
        ;;
      --with-build-local)
        build_local="true"
        ;;
    esac
  done

  if [[ -z "${build_os}" && -z "${build_os_version}" && "${build_all}" != "true" ]]; then
    build_all="true"
  fi

  export KUBEXM_BUILD_ALL="${build_all}"
  export KUBEXM_BUILD_OS="${build_os}"
  export KUBEXM_BUILD_OS_VERSION="${build_os_version}"
  export KUBEXM_BUILD_ARCH="${build_arch:-$(defaults::get_arch_list)}"
  export KUBEXM_BUILD_LOCAL="${build_local}"
}

task::iso_build() {
  local ctx="$1"
  shift
  local args=("$@")

  _task::iso_parse_args "${args[@]}"

  task::run_steps "${ctx}" "${args[@]}" -- \
    "iso.check.deps:${KUBEXM_ROOT}/internal/task/iso/iso_check_deps.sh" \
    "iso.resolve.deps:${KUBEXM_ROOT}/internal/task/iso/iso_resolve_deps.sh" \
    "iso.build.system.packages:${KUBEXM_ROOT}/internal/task/iso/iso_build_system_packages.sh"
}

export -f task::iso_build