#!/bin/bash
# =============================================================================
# KubeXM Container Script - RPM Package Builder
# =============================================================================
# Purpose: Download RPM packages and dependencies, create local repository
# Usage: build-rpm.sh <package_list_file> <output_dir> <arch>
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Global Variables
# -----------------------------------------------------------------------------
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[KubeXM-RPM]"

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log::info() {
  echo "${LOG_PREFIX} [INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log::warn() {
  echo "${LOG_PREFIX} [WARN] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log::error() {
  echo "${LOG_PREFIX} [ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log::debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo "${LOG_PREFIX} [DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $*"
  fi
}

# -----------------------------------------------------------------------------
# Core Functions
# -----------------------------------------------------------------------------

# Download packages using repotrack (yum) or dnf download
rpm::download_packages() {
  local package_list="$1"
  local output_dir="$2"
  local arch="${3:-x86_64}"

  log::info "Downloading RPM packages to ${output_dir}"
  log::info "Architecture: ${arch}"

  mkdir -p "${output_dir}"

  # Determine package manager (yum or dnf)
  local pkg_manager=""
  if command -v dnf &>/dev/null; then
    pkg_manager="dnf"
  elif command -v yum &>/dev/null; then
    pkg_manager="yum"
  else
    log::error "Neither dnf nor yum found"
    return 1
  fi

  log::info "Using package manager: ${pkg_manager}"

  # Read package list and download
  local total_packages=0
  local success_count=0
  local fail_count=0

  while IFS= read -r package || [[ -n "$package" ]]; do
    # Skip empty lines and comments
    [[ -z "$package" || "$package" =~ ^# ]] && continue

    ((total_packages++)) || true
    log::info "Downloading package (${total_packages}): ${package}"

    if [[ "${pkg_manager}" == "dnf" ]]; then
      if dnf download --destdir="${output_dir}" --arch="${arch}" --resolve "${package}" 2>/dev/null; then
        ((success_count++)) || true
        log::info "  ✓ Downloaded: ${package}"
      else
        ((fail_count++)) || true
        log::warn "  ✗ Failed to download: ${package}"
      fi
    else
      # Use repotrack for yum
      if repotrack --arch="${arch}" --download_path="${output_dir}" "${package}" 2>/dev/null; then
        ((success_count++)) || true
        log::info "  ✓ Downloaded: ${package}"
      else
        ((fail_count++)) || true
        log::warn "  ✗ Failed to download: ${package}"
      fi
    fi
  done < "${package_list}"

  log::info "Download complete: ${success_count}/${total_packages} succeeded, ${fail_count} failed"

  return 0
}

# Create repository index using createrepo
rpm::create_repo() {
  local repo_dir="$1"

  log::info "Creating repository index in ${repo_dir}"

  # Determine createrepo command
  local createrepo_cmd=""
  if command -v createrepo_c &>/dev/null; then
    createrepo_cmd="createrepo_c"
  elif command -v createrepo &>/dev/null; then
    createrepo_cmd="createrepo"
  else
    log::error "Neither createrepo nor createrepo_c found"
    return 1
  fi

  log::info "Using: ${createrepo_cmd}"

  # Create repository
  if ${createrepo_cmd} --update "${repo_dir}"; then
    log::info "Repository index created successfully"

    # Count packages
    local pkg_count
    pkg_count=$(find "${repo_dir}" -name "*.rpm" | wc -l)
    log::info "Total packages in repository: ${pkg_count}"

    return 0
  else
    log::error "Failed to create repository index"
    return 1
  fi
}

# Generate repo configuration file
rpm::generate_repo_config() {
  local repo_dir="$1"
  local repo_name="${2:-kubexm-local}"
  local output_file="${3:-${repo_dir}/kubexm-local.repo}"

  log::info "Generating repo configuration: ${output_file}"

  cat > "${output_file}" << EOF
[${repo_name}]
name=KubeXM Local Repository
baseurl=file://${repo_dir}
enabled=1
gpgcheck=0
priority=1
EOF

  log::info "Repo configuration generated"
  return 0
}

# Verify downloaded packages
rpm::verify_packages() {
  local repo_dir="$1"

  log::info "Verifying packages in ${repo_dir}"

  local total=0
  local valid=0
  local invalid=0

  while IFS= read -r rpm_file; do
    ((total++)) || true
    if rpm -K --nosignature "${rpm_file}" &>/dev/null; then
      ((valid++)) || true
    else
      ((invalid++)) || true
      log::warn "Invalid package: ${rpm_file}"
    fi
  done < <(find "${repo_dir}" -name "*.rpm")

  log::info "Verification complete: ${valid}/${total} valid, ${invalid} invalid"

  if [[ ${invalid} -gt 0 ]]; then
    return 1
  fi
  return 0
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
main() {
  local action="${1:-}"

  case "${action}" in
    download)
      local package_list="${2:?Package list file required}"
      local output_dir="${3:?Output directory required}"
      local arch="${4:-x86_64}"
      rpm::download_packages "${package_list}" "${output_dir}" "${arch}"
      ;;
    createrepo)
      local repo_dir="${2:?Repository directory required}"
      rpm::create_repo "${repo_dir}"
      ;;
    genconfig)
      local repo_dir="${2:?Repository directory required}"
      local repo_name="${3:-kubexm-local}"
      local output_file="${4:-${repo_dir}/kubexm-local.repo}"
      rpm::generate_repo_config "${repo_dir}" "${repo_name}" "${output_file}"
      ;;
    verify)
      local repo_dir="${2:?Repository directory required}"
      rpm::verify_packages "${repo_dir}"
      ;;
    full)
      local package_list="${2:?Package list file required}"
      local output_dir="${3:?Output directory required}"
      local arch="${4:-x86_64}"
      rpm::download_packages "${package_list}" "${output_dir}" "${arch}"
      rpm::create_repo "${output_dir}"
      rpm::generate_repo_config "${output_dir}"
      rpm::verify_packages "${output_dir}"
      ;;
    *)
      echo "Usage: ${SCRIPT_NAME} <action> [options]"
      echo ""
      echo "Actions:"
      echo "  download <package_list> <output_dir> [arch]   Download packages and dependencies"
      echo "  createrepo <repo_dir>                         Create repository index"
      echo "  genconfig <repo_dir> [name] [output_file]     Generate repo configuration"
      echo "  verify <repo_dir>                             Verify downloaded packages"
      echo "  full <package_list> <output_dir> [arch]       Full workflow (download + repo + verify)"
      return 1
      ;;
  esac
}

main "$@"
