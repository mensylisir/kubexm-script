#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ISO Build Step - Dependency Resolution
# ==============================================================================
# Reads config to determine LB/storage/CNI settings, resolves package list
# using defaults::get_iso_packages, writes to checkpoint file for downstream.
# ==============================================================================

step::iso.resolve.deps::check() {
  [[ "${KUBEXM_ISO_DEPS_RESOLVED:-false}" == "true" ]]
}

step::iso.resolve.deps::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  # Determine config file
  local config_file="${KUBEXM_CONFIG:-${KUBEXM_ROOT}/config.yaml}"

  # Read deployment parameters from config (or use defaults)
  local lb_type="none"
  local storage_type="none"
  local cni_type="calico"
  local lb_enabled="false"

  if [[ -f "${config_file}" ]]; then
    lb_enabled="$(config::get_loadbalancer_enabled "${config_file}" 2>/dev/null || echo "false")"
    lb_type="$(config::get_loadbalancer_type "${config_file}" 2>/dev/null || echo "none")"
    cni_type="$(config::get_network_plugin "${config_file}" 2>/dev/null || echo "calico")"
    storage_type="$(defaults::get_storage_type 2>/dev/null || echo "none")"

    # If LB is disabled, force lb_type to none
    if [[ "${lb_enabled}" != "true" ]]; then
      lb_type="none"
    fi
  fi

  # Get OS list to resolve packages for
  local build_os_params=""
  if [[ "${KUBEXM_BUILD_ALL:-false}" == "true" ]]; then
    build_os_params="$(defaults::get_build_os_list)"
  elif [[ -n "${KUBEXM_BUILD_OS:-}${KUBEXM_BUILD_OS_VERSION:-}" ]]; then
    build_os_params="${KUBEXM_BUILD_OS:-${KUBEXM_BUILD_OS_VERSION}}"
  else
    build_os_params="$(defaults::get_build_os_list)"
  fi

  # Create checkpoint dir
  local checkpoint_dir="${KUBEXM_ROOT}/.kubexm-checkpoint/iso"
  mkdir -p "${checkpoint_dir}"

  local total_os=0
  local success_os=0

  IFS=',' read -ra os_array <<< "${build_os_params}"

  log::info "Resolving ISO packages"
  log::info "  LB type: ${lb_type} (enabled: ${lb_enabled})"
  log::info "  Storage type: ${storage_type}"
  log::info "  CNI type: ${cni_type}"
  log::info "  OS count: ${#os_array[@]}"

  for os in "${os_array[@]}"; do
    [[ -z "${os}" ]] && continue
    ((total_os++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

    local pkg_file="${checkpoint_dir}/packages-${os}.txt"

    log::info "  Resolving packages for ${os}..."

    # Call defaults::get_iso_packages
    local packages
    packages=$(defaults::get_iso_packages "${os}" "${lb_type}" "${storage_type}" "${cni_type}" 2>/dev/null) || {
      log::warn "  Failed to resolve packages for ${os}, using base packages only"
      packages=$(defaults::get_iso_packages "${os}" "none" "none" "calico")
    }

    # Write to checkpoint file
    {
      echo "# KubeXM ISO Package List"
      echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "# OS: ${os}"
      echo "# LB type: ${lb_type}"
      echo "# Storage type: ${storage_type}"
      echo "# CNI type: ${cni_type}"
      echo ""
      echo "${packages}"
    } > "${pkg_file}"

    local pkg_count
    pkg_count=$(echo "${packages}" | wc -l)
    log::info "    ✓ ${pkg_count} packages resolved for ${os} → ${pkg_file}"
    ((success_os++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  done

  log::info "Package resolution complete: ${success_os}/${total_os} OS processed"
  export KUBEXM_ISO_DEPS_RESOLVED="true"
  export KUBEXM_ISO_CHECKPOINT_DIR="${checkpoint_dir}"
}

step::iso.resolve.deps::rollback() {
  # Remove checkpoint files on rollback
  local checkpoint_dir="${KUBEXM_ISO_CHECKPOINT_DIR:-${KUBEXM_ROOT}/.kubexm-checkpoint/iso}"
  rm -f "${checkpoint_dir}"/packages-*.txt
  unset KUBEXM_ISO_DEPS_RESOLVED KUBEXM_ISO_CHECKPOINT_DIR
}

step::iso.resolve.deps::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
