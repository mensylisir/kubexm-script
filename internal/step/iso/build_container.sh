#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: iso.build.container
# 容器化制作 ISO（可制作任意 OS/架构的 ISO，不依赖本机环境）
# 输出路径: ${DOWNLOAD_DIR}/iso/${os_name}/${os_version}/${arch}/${os_name}-${os_version}-${arch}.iso
# ==============================================================================

step::iso.build.container::check() {
  return 1  # always need to build if requested
}

step::iso.build.container::run() {
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

  log::info "Building ISO in container: ${os_name} ${os_version} ${arch}"
  log::info "Output: ${output_file}"

  # Call the Docker-based ISO build
  "${KUBEXM_ROOT}/internal/utils/resources/build_docker.sh" \
    --os "${os_name}" \
    --os-version "${os_version}" \
    --arch "${arch}" \
    --output "${output_file}" || return 1

  log::info "ISO built successfully in container: ${output_file}"
}

step::iso.build.container::rollback() { return 0; }

step::iso.build.container::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
