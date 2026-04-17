#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: iso.build.local
# 本地制作 ISO（只能制作与本机同版本同架构的 ISO）
# 输出路径: ${DOWNLOAD_DIR}/iso/${os_name}/${os_version}/${arch}/${os_name}-${os_version}-${arch}.iso
# ==============================================================================

step::iso.build.local::check() {
  return 1  # always need to build if requested
}

step::iso.build.local::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local os_name="${KUBEXM_ISO_OS_NAME:-$(defaults::get_iso_os_name)}"
  local os_version="${KUBEXM_ISO_OS_VERSION:-$(defaults::get_iso_os_version)}"
  local arch="${KUBEXM_ISO_ARCH:-$(defaults::get_iso_arch)}"

  local download_dir="${KUBEXM_PACKAGES_DIR:-${KUBEXM_ROOT}/packages}"
  local output_dir="${download_dir}/iso/${os_name}/${os_version}/${arch}"
  local output_file="${output_dir}/${os_name}-${os_version}-${arch}.iso"

  mkdir -p "${output_dir}"

  log::info "Building ISO locally: ${os_name} ${os_version} ${arch}"
  log::info "Output: ${output_file}"

  # Call the ISO build.local utility
  "${KUBEXM_ROOT}/internal/utils/resources/build_iso.sh" \
    --os "${os_name}" \
    --os-version "${os_version}" \
    --arch "${arch}" \
    --output "${output_file}" \
    --local || return 1

  log::info "ISO built successfully: ${output_file}"
}

step::iso.build.local::rollback() { return 0; }

step::iso.build.local::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
