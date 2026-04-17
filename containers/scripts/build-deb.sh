#!/bin/bash
# =============================================================================
# KubeXM Container Script - DEB Package Builder
# =============================================================================
# Purpose: Download DEB packages and dependencies, create local repository
# Usage: build-deb.sh <package_list_file> <output_dir> <arch>
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Global Variables
# -----------------------------------------------------------------------------
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[KubeXM-DEB]"

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

# Download packages using apt-get download
deb::download_packages() {
  local package_list="$1"
  local output_dir="$2"
  local arch="${3:-amd64}"

  log::info "Downloading DEB packages to ${output_dir}"
  log::info "Architecture: ${arch}"

  mkdir -p "${output_dir}"
  cd "${output_dir}"

  # Update package cache
  log::info "Updating package cache..."
  apt-get update -qq

  # Collect all packages with dependencies using apt-cache
  log::info "Collecting packages and dependencies..."
  local all_packages=""
  local total_packages=0

  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -z "$package" || "$package" =~ ^# ]] && continue
    ((total_packages++)) || true
    log::info "  [${total_packages}] ${package}"

    # Get recursive dependencies via apt-cache
    local deps
    deps=$(apt-cache depends --recurse --no-recommends --no-suggests \
      --no-conflicts --no-breaks --no-replaces --no-enhances \
      "${package}" 2>/dev/null | \
      grep "^Depends:" | awk '{print $2}' | sed 's/<.*>//g' | sort -u)

    all_packages="${all_packages}${package}"$' '
    for dep in ${deps}; do
      all_packages="${all_packages}${dep}"$' '
    done
  done < "${package_list}"

  # Deduplicate
  local unique_packages
  unique_packages=$(echo "${all_packages}" | tr ' ' '\n' | sort -u | grep -v '^$')
  local unique_count
  unique_count=$(echo "${unique_packages}" | wc -l)
  log::info "Total unique packages to download: ${unique_count}"

  # Filter out already-installed packages
  local installed
  installed=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | sort)
  local to_download
  to_download=$(comm -23 <(echo "${unique_packages}") <(echo "${installed}") | grep -v '^$')

  log::info "Packages to download (excluding installed): $(echo "${to_download}" | wc -l)"

  # Download
  local success_count=0
  local fail_count=0
  local download_count=0

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    ((download_count++)) || true

    if apt-get download "${pkg}:${arch}" 2>/dev/null; then
      ((success_count++)) || true
    elif apt-get download "${pkg}" 2>/dev/null; then
      ((success_count++)) || true
    else
      ((fail_count++)) || true
      log::warn "  ✗ Failed: ${pkg}"
    fi

    [[ $((download_count % 10)) -eq 0 ]] && log::info "  Progress: ${download_count}/${unique_count}"
  done <<< "${to_download}"

  log::info "Download complete: ${success_count} succeeded, ${fail_count} failed"

  return 0
}

# Create repository index using dpkg-scanpackages
deb::create_repo() {
  local repo_dir="$1"

  log::info "Creating repository index in ${repo_dir}"

  cd "${repo_dir}"

  # Create Packages file
  if dpkg-scanpackages . /dev/null > Packages 2>/dev/null; then
    log::info "Created Packages file"
  else
    log::error "Failed to create Packages file"
    return 1
  fi

  # Compress Packages file
  if gzip -9c Packages > Packages.gz; then
    log::info "Created Packages.gz"
  else
    log::warn "Failed to create Packages.gz"
  fi

  # Create Release file
  cat > Release << EOF
Origin: KubeXM
Label: KubeXM Local Repository
Suite: stable
Codename: kubexm
Architectures: amd64 arm64
Components: main
Description: KubeXM Offline Package Repository
EOF

  log::info "Created Release file"

  # Count packages
  local pkg_count
  pkg_count=$(find "${repo_dir}" -name "*.deb" | wc -l)
  log::info "Total packages in repository: ${pkg_count}"

  return 0
}

# Generate sources.list configuration
deb::generate_sources_list() {
  local repo_dir="$1"
  local output_file="${2:-${repo_dir}/kubexm-local.list}"

  log::info "Generating sources.list: ${output_file}"

  cat > "${output_file}" << EOF
deb [trusted=yes] file://${repo_dir} ./
EOF

  log::info "Sources list configuration generated"
  return 0
}

# Verify downloaded packages
deb::verify_packages() {
  local repo_dir="$1"

  log::info "Verifying packages in ${repo_dir}"

  local total=0
  local valid=0
  local invalid=0

  while IFS= read -r deb_file; do
    ((total++)) || true
    if dpkg-deb --info "${deb_file}" &>/dev/null; then
      ((valid++)) || true
    else
      ((invalid++)) || true
      log::warn "Invalid package: ${deb_file}"
    fi
  done < <(find "${repo_dir}" -name "*.deb")

  log::info "Verification complete: ${valid}/${total} valid, ${invalid} invalid"

  if [[ ${invalid} -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Generate package summary
deb::generate_summary() {
  local repo_dir="$1"
  local output_file="${2:-${repo_dir}/PACKAGE_SUMMARY.txt}"

  log::info "Generating package summary: ${output_file}"

  {
    echo "KubeXM DEB Package Repository Summary"
    echo "========================================"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Total Packages: $(find "${repo_dir}" -name "*.deb" | wc -l)"
    echo "Total Size: $(du -sh "${repo_dir}" | cut -f1)"
    echo ""
    echo "Package List:"
    echo "-------------"
    find "${repo_dir}" -name "*.deb" -exec basename {} \; | sort
  } > "${output_file}"

  log::info "Package summary generated"
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
      local arch="${4:-amd64}"
      deb::download_packages "${package_list}" "${output_dir}" "${arch}"
      ;;
    createrepo)
      local repo_dir="${2:?Repository directory required}"
      deb::create_repo "${repo_dir}"
      ;;
    genconfig)
      local repo_dir="${2:?Repository directory required}"
      local output_file="${3:-${repo_dir}/kubexm-local.list}"
      deb::generate_sources_list "${repo_dir}" "${output_file}"
      ;;
    verify)
      local repo_dir="${2:?Repository directory required}"
      deb::verify_packages "${repo_dir}"
      ;;
    summary)
      local repo_dir="${2:?Repository directory required}"
      deb::generate_summary "${repo_dir}"
      ;;
    full)
      local package_list="${2:?Package list file required}"
      local output_dir="${3:?Output directory required}"
      local arch="${4:-amd64}"
      deb::download_packages "${package_list}" "${output_dir}" "${arch}"
      deb::create_repo "${output_dir}"
      deb::generate_sources_list "${output_dir}"
      deb::verify_packages "${output_dir}"
      deb::generate_summary "${output_dir}"
      ;;
    *)
      echo "Usage: ${SCRIPT_NAME} <action> [options]"
      echo ""
      echo "Actions:"
      echo "  download <package_list> <output_dir> [arch]   Download packages and dependencies"
      echo "  createrepo <repo_dir>                         Create repository index"
      echo "  genconfig <repo_dir> [output_file]            Generate sources.list configuration"
      echo "  verify <repo_dir>                             Verify downloaded packages"
      echo "  summary <repo_dir>                            Generate package summary"
      echo "  full <package_list> <output_dir> [arch]       Full workflow"
      return 1
      ;;
  esac
}

main "$@"
