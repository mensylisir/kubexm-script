#!/bin/bash
# =============================================================================
# KubeXM Script - Package Build with Conditional Selection
# =============================================================================
# Purpose: Build system packages with intelligent conditional selection
# Supports 24 deployment scenarios through configuration-driven package selection
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Script Root Detection
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEXM_ROOT="${KUBEXM_ROOT:-$(cd "${SCRIPT_DIR}/../../.." && pwd)}"
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-${KUBEXM_ROOT}}"

# Source required libraries
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

# Base packages required for all deployments
declare -a BASE_PACKAGES=(
  "curl"
  "wget"
  "tar"
  "gzip"
  "xz"
  "conntrack"
  "conntrack-tools"
  "ethtool"
  "socat"
  "ebtables"
  "ipset"
  "ipvsadm"
  "iptables"
  "iproute"
  "bash-completion"
  "openssh-clients"
  "openssl"
)

# HAProxy packages
declare -a HAPROXY_PACKAGES=(
  "haproxy"
)

# Nginx packages
declare -a NGINX_PACKAGES=(
  "nginx"
)

# Keepalived packages
declare -a KEEPALIVED_PACKAGES=(
  "keepalived"
)

# Container runtime packages
declare -a CONTAINERD_PACKAGES=(
  "containerd.io"
)

# SELinux packages (for RPM-based systems)
declare -a SELINUX_PACKAGES=(
  "container-selinux"
  "selinux-policy-base"
)

# Chrony/NTP packages
declare -a NTP_PACKAGES=(
  "chrony"
)

# -----------------------------------------------------------------------------
# Package List Generation
# -----------------------------------------------------------------------------

# Generate package list based on configuration
packages::generate_list() {
  local config_file="${1:-}"
  local output_file="${2:-/tmp/kubexm_packages.txt}"
  local os_type="${3:-$(defaults::get_os_type)}"

  log::info "Generating package list"
  log::info "  Config: ${config_file:-default}"
  log::info "  Output: ${output_file}"
  log::info "  OS Type: ${os_type}"

  # Initialize package array
  local packages=()

  # Always include base packages
  packages+=("${BASE_PACKAGES[@]}")
  log::info "  Added base packages: ${#BASE_PACKAGES[@]}"

  # Get configuration values
  local lb_enabled=""
  local lb_mode=""
  local lb_type=""
  local k8s_type=""
  local etcd_type=""
  local ntp_enabled=""
  local selinux_enabled=""

  if [[ -n "${config_file}" && -f "${config_file}" ]]; then
    # Read from config file using xmparser
    lb_enabled=$(config::get_loadbalancer_enabled "${config_file}" 2>/dev/null || echo "false")
    lb_mode=$(config::get_loadbalancer_mode "${config_file}" 2>/dev/null || echo "none")
    lb_type=$(config::get_loadbalancer_type "${config_file}" 2>/dev/null || echo "none")
    k8s_type=$(config::get_kubernetes_type "${config_file}" 2>/dev/null || echo "kubeadm")
    etcd_type=$(config::get_etcd_type "${config_file}" 2>/dev/null || echo "kubeadm")
    ntp_enabled=$(config::get "ntp.enabled" "${config_file}" 2>/dev/null || echo "true")
    selinux_enabled=$(config::get "security.selinux.enabled" "${config_file}" 2>/dev/null || echo "true")
  else
    # Use environment variables or defaults
    lb_enabled="${KUBEXM_LB_ENABLED:-$(defaults::get_loadbalancer_enabled)}"
    lb_mode="${KUBEXM_LB_MODE:-$(defaults::get_loadbalancer_mode)}"
    lb_type="${KUBEXM_LB_TYPE:-$(defaults::get_loadbalancer_type)}"
    k8s_type="${KUBEXM_K8S_TYPE:-$(defaults::get_kubernetes_type)}"
    etcd_type="${KUBEXM_ETCD_TYPE:-$(defaults::get_etcd_type)}"
    ntp_enabled="${KUBEXM_NTP_ENABLED:-true}"
    selinux_enabled="${KUBEXM_SELINUX_ENABLED:-true}"
  fi

  log::info "Configuration:"
  log::info "  LoadBalancer enabled: ${lb_enabled}"
  log::info "  LoadBalancer mode: ${lb_mode}"
  log::info "  LoadBalancer type: ${lb_type}"
  log::info "  Kubernetes type: ${k8s_type}"
  log::info "  etcd type: ${etcd_type}"

  # Conditional: LoadBalancer packages
  if [[ "${lb_enabled}" == "true" ]]; then
    case "${lb_type}" in
      haproxy|kubexm-kh)
        log::info "  Adding HAProxy + Keepalived packages"
        packages+=("${HAPROXY_PACKAGES[@]}")
        packages+=("${KEEPALIVED_PACKAGES[@]}")
        ;;
      nginx|kubexm-kn)
        log::info "  Adding Nginx + Keepalived packages"
        packages+=("${NGINX_PACKAGES[@]}")
        packages+=("${KEEPALIVED_PACKAGES[@]}")
        ;;
      kube-vip)
        log::info "  kube-vip mode: no additional packages needed"
        ;;
      existing)
        log::info "  Using existing LoadBalancer: no packages needed"
        ;;
      *)
        log::warn "  Unknown LoadBalancer type: ${lb_type}"
        ;;
    esac
  else
    log::info "  LoadBalancer disabled: skipping LB packages"
  fi

  # Conditional: Container runtime packages
  if [[ "${k8s_type}" == "kubexm" ]]; then
    log::info "  Adding containerd packages (kubexm mode)"
    packages+=("${CONTAINERD_PACKAGES[@]}")
  fi

  # Conditional: NTP packages
  if [[ "${ntp_enabled}" == "true" ]]; then
    log::info "  Adding NTP packages"
    packages+=("${NTP_PACKAGES[@]}")
  fi

  # Conditional: SELinux packages (RPM-based only)
  if [[ "${selinux_enabled}" == "true" ]]; then
    case "${os_type}" in
      centos|rocky|almalinux|rhel|fedora|kylin|openeuler)
        log::info "  Adding SELinux packages"
        packages+=("${SELINUX_PACKAGES[@]}")
        ;;
    esac
  fi

  # Deduplicate and sort
  local unique_packages
  unique_packages=$(printf '%s\n' "${packages[@]}" | sort -u)

  # Write to output file
  echo "# KubeXM Package List" > "${output_file}"
  echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "${output_file}"
  echo "# Configuration:" >> "${output_file}"
  echo "#   lb_enabled: ${lb_enabled}" >> "${output_file}"
  echo "#   lb_type: ${lb_type}" >> "${output_file}"
  echo "#   k8s_type: ${k8s_type}" >> "${output_file}"
  echo "#   etcd_type: ${etcd_type}" >> "${output_file}"
  echo "" >> "${output_file}"

  echo "${unique_packages}" >> "${output_file}"

  local pkg_count
  pkg_count=$(echo "${unique_packages}" | wc -l)
  log::info "Generated package list: ${pkg_count} packages"

  return 0
}

# Generate package list for specific scenario
packages::generate_scenario_list() {
  local scenario="$1"
  local output_file="$2"
  local os_type="${3:-$(defaults::get_os_type)}"

  log::info "Generating package list for scenario: ${scenario}"

  # Parse scenario: format is k8s_type-etcd_type-lb_mode-lb_type
  # Examples: kubeadm-stacked-none-none, kubexm-external-external-haproxy

  local k8s_type etcd_type lb_mode lb_type

  IFS='-' read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  # Set environment variables for package generation
  export KUBEXM_K8S_TYPE="${k8s_type}"
  export KUBEXM_ETCD_TYPE="${etcd_type}"
  export KUBEXM_LB_MODE="${lb_mode}"
  export KUBEXM_LB_TYPE="${lb_type:-none}"

  # Determine if LB is enabled
  if [[ "${lb_mode}" != "none" ]]; then
    export KUBEXM_LB_ENABLED="true"
  else
    export KUBEXM_LB_ENABLED="false"
  fi

  packages::generate_list "" "${output_file}" "${os_type}"
}

# -----------------------------------------------------------------------------
# Package Building Functions
# -----------------------------------------------------------------------------

# Build packages using Docker container
packages::build_with_docker() {
  local os_name="$1"
  local package_list="$2"
  local output_dir="$3"
  local arch="${4:-$(defaults::get_arch)}"

  log::info "Building packages using Docker"
  log::info "  OS: ${os_name}"
  log::info "  Package list: ${package_list}"
  log::info "  Output: ${output_dir}"
  log::info "  Architecture: ${arch}"

  # Call build-docker.sh to run package build
  "${KUBEXM_SCRIPT_ROOT}/internal/utils/resources/build_docker.sh" run \
    "${os_name}" "${package_list}" "${output_dir}" "${arch}"
}

# Build packages directly (without Docker)
packages::build_direct() {
  local package_list="$1"
  local output_dir="$2"
  local arch="${3:-$(uname -m)}"

  log::info "Building packages directly"
  log::info "  Package list: ${package_list}"
  log::info "  Output: ${output_dir}"
  log::info "  Architecture: ${arch}"

  mkdir -p "${output_dir}"

  # Detect OS type
  local os_type=""
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    case "${ID}" in
      centos|rhel|rocky|almalinux|fedora|kylin|openeuler)
        os_type="rpm"
        ;;
      ubuntu|debian|uos)
        os_type="deb"
        ;;
      *)
        log::error "Unsupported OS: ${ID}"
        return 1
        ;;
    esac
  else
    log::error "Cannot detect OS type"
    return 1
  fi

  case "${os_type}" in
    rpm)
      packages::build_rpm_direct "${package_list}" "${output_dir}" "${arch}"
      ;;
    deb)
      packages::build_deb_direct "${package_list}" "${output_dir}" "${arch}"
      ;;
  esac
}

# Build RPM packages directly
packages::build_rpm_direct() {
  local package_list="$1"
  local output_dir="$2"
  local arch="${3:-$(defaults::get_arch)}"

  log::info "Building RPM packages"

  cd "${output_dir}"

  local total=0
  local success=0
  local failed=0

  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -z "$package" || "$package" =~ ^# ]] && continue
    ((total++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

    log::info "  Downloading: ${package}"

    if command -v dnf &>/dev/null; then
      if dnf download --destdir="${output_dir}" --arch="${arch}" --resolve "${package}" 2>/dev/null; then
        ((success++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      else
        ((failed++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
        log::warn "  Failed: ${package}"
      fi
    elif command -v yumdownloader &>/dev/null; then
      if yumdownloader --destdir="${output_dir}" --archlist="${arch}" --resolve "${package}" 2>/dev/null; then
        ((success++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      else
        ((failed++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
        log::warn "  Failed: ${package}"
      fi
    else
      log::error "Neither dnf nor yumdownloader available"
      return 1
    fi
  done < "${package_list}"

  log::info "Download complete: ${success}/${total} succeeded"

  # Create repository
  if command -v createrepo_c &>/dev/null; then
    createrepo_c "${output_dir}"
  elif command -v createrepo &>/dev/null; then
    createrepo "${output_dir}"
  else
    log::warn "createrepo not available, skipping repository creation"
  fi

  return 0
}

# Build DEB packages directly
packages::build_deb_direct() {
  local package_list="$1"
  local output_dir="$2"
  local arch="${3:-$(defaults::get_arch)}"

  log::info "Building DEB packages"

  cd "${output_dir}"

  apt-get update -qq

  local total=0
  local success=0
  local failed=0

  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -z "$package" || "$package" =~ ^# ]] && continue
    ((total++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

    log::info "  Downloading: ${package}"

    if apt-get download "${package}" 2>/dev/null; then
      ((success++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      ((failed++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      log::warn "  Failed: ${package}"
    fi
  done < "${package_list}"

  log::info "Download complete: ${success}/${total} succeeded"

  # Create repository index
  dpkg-scanpackages . /dev/null > Packages 2>/dev/null || true
  gzip -9c Packages > Packages.gz 2>/dev/null || true

  return 0
}

# -----------------------------------------------------------------------------
# Multi-OS Package Building
# -----------------------------------------------------------------------------

# Build packages for multiple OS
packages::build_multi_os() {
  local config_file="$1"
  local output_base="$2"
  local os_list="${3:-centos7,rocky9,ubuntu22}"

  log::info "Building packages for multiple OS"
  log::info "  Config: ${config_file}"
  log::info "  Output base: ${output_base}"
  log::info "  OS list: ${os_list}"

  IFS=',' read -ra os_array <<< "${os_list}"

  for os in "${os_array[@]}"; do
    log::info "Building for: ${os}"

    local os_output="${output_base}/${os}"
    local package_list="${os_output}/packages.txt"

    mkdir -p "${os_output}"

    # Generate package list
    packages::generate_list "${config_file}" "${package_list}" "${os}"

    # Build packages using Docker
    packages::build_with_docker "${os}" "${package_list}" "${os_output}/packages"
  done

  log::info "Multi-OS package build complete"
}

# Build packages for multiple architectures
packages::build_multi_arch() {
  local os_name="$1"
  local config_file="$2"
  local output_base="$3"
  local arch_list="${4:-amd64,arm64}"

  log::info "Building packages for multiple architectures"
  log::info "  OS: ${os_name}"
  log::info "  Architectures: ${arch_list}"

  IFS=',' read -ra arch_array <<< "${arch_list}"

  # Generate package list once
  local package_list="${output_base}/packages.txt"
  packages::generate_list "${config_file}" "${package_list}" "${os_name}"

  for arch in "${arch_array[@]}"; do
    log::info "Building for architecture: ${arch}"

    local arch_output="${output_base}/${arch}"
    mkdir -p "${arch_output}"

    # Map architecture name
    local rpm_arch deb_arch
    case "${arch}" in
      amd64|x86_64)
        rpm_arch="x86_64"
        deb_arch="amd64"
        ;;
      arm64|aarch64)
        rpm_arch="aarch64"
        deb_arch="arm64"
        ;;
      *)
        rpm_arch="${arch}"
        deb_arch="${arch}"
        ;;
    esac

    # Determine which arch to use based on OS
    local use_arch="${rpm_arch}"
    case "${os_name}" in
      ubuntu*|debian*|uos*)
        use_arch="${deb_arch}"
        ;;
    esac

    packages::build_with_docker "${os_name}" "${package_list}" "${arch_output}" "${use_arch}"
  done

  log::info "Multi-arch package build complete"
}

# -----------------------------------------------------------------------------
# Scenario-Based Building
# -----------------------------------------------------------------------------

# Build packages for all 24 scenarios
packages::build_all_scenarios() {
  local os_name="$1"
  local output_base="$2"

  log::info "Building packages for all deployment scenarios"

  # Define all scenarios
  local scenarios=(
    # kubeadm + stacked etcd scenarios
    "kubeadm-stacked-none-none"
    "kubeadm-stacked-internal-haproxy"
    "kubeadm-stacked-internal-nginx"
    "kubeadm-stacked-external-haproxy"
    "kubeadm-stacked-external-nginx"
    "kubeadm-stacked-kube-vip-none"

    # kubeadm + external etcd scenarios
    "kubeadm-external-none-none"
    "kubeadm-external-internal-haproxy"
    "kubeadm-external-internal-nginx"
    "kubeadm-external-external-haproxy"
    "kubeadm-external-external-nginx"
    "kubeadm-external-kube-vip-none"

    # kubexm + stacked etcd scenarios
    "kubexm-stacked-none-none"
    "kubexm-stacked-internal-haproxy"
    "kubexm-stacked-internal-nginx"
    "kubexm-stacked-external-haproxy"
    "kubexm-stacked-external-nginx"
    "kubexm-stacked-kube-vip-none"

    # kubexm + external etcd scenarios
    "kubexm-external-none-none"
    "kubexm-external-internal-haproxy"
    "kubexm-external-internal-nginx"
    "kubexm-external-external-haproxy"
    "kubexm-external-external-nginx"
    "kubexm-external-kube-vip-none"
  )

  local total=${#scenarios[@]}
  local current=0

  for scenario in "${scenarios[@]}"; do
    ((current++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    log::info "Building scenario ${current}/${total}: ${scenario}"

    local scenario_output="${output_base}/scenarios/${scenario}"
    local package_list="${scenario_output}/packages.txt"

    mkdir -p "${scenario_output}"

    packages::generate_scenario_list "${scenario}" "${package_list}" "${os_name}"
    packages::build_with_docker "${os_name}" "${package_list}" "${scenario_output}/packages"
  done

  log::info "All ${total} scenarios built successfully"
}

# Build optimized package set (merged common packages)
packages::build_optimized() {
  local os_name="$1"
  local output_base="$2"
  local scenarios="${3:-all}"

  log::info "Building optimized package set"
  log::info "  OS: ${os_name}"
  log::info "  Output: ${output_base}"

  mkdir -p "${output_base}"

  # Generate all package lists and merge
  local all_packages_file="${output_base}/all_packages.txt"
  > "${all_packages_file}"

  # Define scenario groups for optimization
  local -A package_groups=(
    ["base"]="kubeadm-stacked-none-none"
    ["haproxy"]="kubeadm-stacked-internal-haproxy"
    ["nginx"]="kubeadm-stacked-internal-nginx"
    ["kubexm"]="kubexm-stacked-none-none"
  )

  for group in "${!package_groups[@]}"; do
    local scenario="${package_groups[$group]}"
    local temp_file="/tmp/kubexm_pkg_${group}.txt"

    packages::generate_scenario_list "${scenario}" "${temp_file}" "${os_name}"

    cat "${temp_file}" >> "${all_packages_file}"
  done

  # Deduplicate
  sort -u "${all_packages_file}" | grep -v '^#' | grep -v '^$' > "${all_packages_file}.tmp"
  mv "${all_packages_file}.tmp" "${all_packages_file}"

  log::info "Total unique packages: $(wc -l < "${all_packages_file}")"

  # Build all packages at once
  packages::build_with_docker "${os_name}" "${all_packages_file}" "${output_base}/packages"

  log::info "Optimized package build complete"
}

# -----------------------------------------------------------------------------
# Verification Functions
# -----------------------------------------------------------------------------

# Verify built packages
packages::verify() {
  local package_dir="$1"

  log::info "Verifying packages in: ${package_dir}"

  local total=0
  local valid=0
  local invalid=0

  # Check for RPM packages
  while IFS= read -r rpm_file; do
    ((total++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    if rpm -K --nosignature "${rpm_file}" &>/dev/null; then
      ((valid++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      ((invalid++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      log::warn "Invalid RPM: ${rpm_file}"
    fi
  done < <(find "${package_dir}" -name "*.rpm" 2>/dev/null)

  # Check for DEB packages
  while IFS= read -r deb_file; do
    ((total++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    if dpkg-deb --info "${deb_file}" &>/dev/null; then
      ((valid++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      ((invalid++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      log::warn "Invalid DEB: ${deb_file}"
    fi
  done < <(find "${package_dir}" -name "*.deb" 2>/dev/null)

  log::info "Verification: ${valid}/${total} valid, ${invalid} invalid"

  [[ ${invalid} -eq 0 ]]
}

# Generate package manifest
packages::generate_manifest() {
  local package_dir="$1"
  local output_file="${2:-${package_dir}/MANIFEST.txt}"

  log::info "Generating package manifest: ${output_file}"

  {
    echo "KubeXM Package Manifest"
    echo "========================"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Directory: ${package_dir}"
    echo ""
    echo "Packages:"
    echo "---------"

    find "${package_dir}" \( -name "*.rpm" -o -name "*.deb" \) -exec basename {} \; | sort

    echo ""
    echo "Statistics:"
    echo "-----------"
    echo "Total files: $(find "${package_dir}" \( -name "*.rpm" -o -name "*.deb" \) | wc -l)"
    echo "Total size: $(du -sh "${package_dir}" | cut -f1)"
  } > "${output_file}"

  log::info "Manifest generated"
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
packages::main() {
  local action="${1:-}"
  shift || true

  case "${action}" in
    generate)
      local config_file="${1:-}"
      local output_file="${2:-/tmp/kubexm_packages.txt}"
      local os_type="${3:-$(defaults::get_os_type)}"
      packages::generate_list "${config_file}" "${output_file}" "${os_type}"
      ;;
    generate-scenario)
      local scenario="${1:?Scenario required}"
      local output_file="${2:?Output file required}"
      local os_type="${3:-$(defaults::get_os_type)}"
      packages::generate_scenario_list "${scenario}" "${output_file}" "${os_type}"
      ;;
    build)
      local os_name="${1:?OS name required}"
      local package_list="${2:?Package list required}"
      local output_dir="${3:?Output directory required}"
      local arch="${4:-$(defaults::get_arch)}"
      packages::build_with_docker "${os_name}" "${package_list}" "${output_dir}" "${arch}"
      ;;
    build-direct)
      local package_list="${1:?Package list required}"
      local output_dir="${2:?Output directory required}"
      local arch="${3:-$(uname -m)}"
      packages::build_direct "${package_list}" "${output_dir}" "${arch}"
      ;;
    build-multi-os)
      local config_file="${1:?Config file required}"
      local output_base="${2:?Output base directory required}"
      local os_list="${3:-centos7,rocky9,ubuntu22}"
      packages::build_multi_os "${config_file}" "${output_base}" "${os_list}"
      ;;
    build-multi-arch)
      local os_name="${1:?OS name required}"
      local config_file="${2:?Config file required}"
      local output_base="${3:?Output base directory required}"
      local arch_list="${4:-amd64,arm64}"
      packages::build_multi_arch "${os_name}" "${config_file}" "${output_base}" "${arch_list}"
      ;;
    build-all-scenarios)
      local os_name="${1:?OS name required}"
      local output_base="${2:?Output base directory required}"
      packages::build_all_scenarios "${os_name}" "${output_base}"
      ;;
    build-optimized)
      local os_name="${1:?OS name required}"
      local output_base="${2:?Output base directory required}"
      packages::build_optimized "${os_name}" "${output_base}"
      ;;
    verify)
      local package_dir="${1:?Package directory required}"
      packages::verify "${package_dir}"
      ;;
    manifest)
      local package_dir="${1:?Package directory required}"
      local output_file="${2:-}"
      packages::generate_manifest "${package_dir}" "${output_file}"
      ;;
    help|--help|-h)
      cat << 'EOF'
KubeXM Package Build with Conditional Selection

Usage: build-packages.sh <action> [options]

Actions:
  generate [config] [output] [os]         Generate package list from config
  generate-scenario <scenario> <output>   Generate package list for scenario
  build <os> <pkg_list> <output> [arch]   Build packages using Docker
  build-direct <pkg_list> <output> [arch] Build packages directly (no Docker)
  build-multi-os <config> <output> [os_list]
                                          Build for multiple OS
  build-multi-arch <os> <config> <output> [arch_list]
                                          Build for multiple architectures
  build-all-scenarios <os> <output>       Build for all 24 scenarios
  build-optimized <os> <output>           Build optimized package set
  verify <package_dir>                    Verify built packages
  manifest <package_dir> [output]         Generate package manifest
  help                                    Show this help

Scenarios format: k8s_type-etcd_type-lb_mode-lb_type
Examples:
  kubeadm-stacked-none-none
  kubexm-external-external-haproxy
  kubeadm-stacked-internal-nginx

Environment Variables:
  KUBEXM_LB_ENABLED     LoadBalancer enabled (true/false)
  KUBEXM_LB_MODE        LoadBalancer mode (none/internal/external/kube-vip)
  KUBEXM_LB_TYPE        LoadBalancer type (haproxy/nginx/kube-vip/existing)
  KUBEXM_K8S_TYPE       Kubernetes type (kubeadm/kubexm)
  KUBEXM_ETCD_TYPE      etcd type (kubeadm/kubexm)
  KUBEXM_NTP_ENABLED    NTP enabled (true/false)
  KUBEXM_SELINUX_ENABLED SELinux enabled (true/false)

Examples:
  # Generate package list with default config
  build-packages.sh generate

  # Generate for specific scenario
  build-packages.sh generate-scenario kubexm-external-haproxy /tmp/packages.txt

  # Build packages for CentOS 7
  build-packages.sh build centos7 /tmp/packages.txt /output/packages

  # Build for multiple OS
  build-packages.sh build-multi-os config.yaml /output centos7,ubuntu22

  # Build optimized set for all scenarios
  build-packages.sh build-optimized rocky9 /output
EOF
      ;;
    *)
      log::error "Unknown action: ${action}"
      echo "Use 'build-packages.sh help' for usage information"
      return 1
      ;;
  esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  packages::main "$@"
fi
