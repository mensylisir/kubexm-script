#!/bin/bash
# =============================================================================
# KubeXM Script - System Packages ISO Builder
# =============================================================================
# Purpose: Build ISO containing ONLY system dependency packages
# Packages: haproxy, nginx, keepalived, conntrack, etc.
# Workflow: Use Docker containers to download packages, then create ISO
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Script Root Detection
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEXM_ROOT="${KUBEXM_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-${KUBEXM_ROOT}}"

# Source required libraries
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/resources/build_packages.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
SYSTEM_PACKAGE_ISO_DIR="${KUBEXM_SCRIPT_ROOT}/templates/system-packages-iso"
DEFAULT_ISO_LABEL="KUBEXM_SYSTEM_PKGS"

# Supported OS for system packages (must match parse_os entries)
declare -a SYSTEM_PACKAGE_OS=(
  # RPM-based
  "centos7"
  "centos8"
  "rocky8"
  "rocky9"
  "almalinux8"
  "almalinux9"
  "rhel7"
  "rhel8"
  "rhel9"
  "ol8"
  "ol9"
  "anolis8"
  "anolis9"
  "fedora39"
  "fedora40"
  "fedora41"
  "fedora42"
  "kylin10"
  "openeuler22"
  "uos20"
  # DEB-based
  "ubuntu20"
  "ubuntu22"
  "ubuntu24"
  "debian10"
  "debian11"
  "debian12"
)

# Note: System packages are now dynamically generated using defaults::get_system_packages()
# This includes all necessary packages based on OS type, runtime, CNI, and loadbalancer configuration

# -----------------------------------------------------------------------------
# ISO Structure Creation
# -----------------------------------------------------------------------------

# Create system packages ISO directory structure
system_iso::create_structure() {
  local iso_root="$1"

  log::info "Creating system packages ISO structure: ${iso_root}"

  # Create directories for each OS
  for os in "${SYSTEM_PACKAGE_OS[@]}"; do
    mkdir -p "${iso_root}/${os}"/{packages,repo}
  done

  # Create install directory
  mkdir -p "${iso_root}/install"

  log::info "System packages ISO structure created"
}

# Generate package list for Docker build using full system package definitions
system_iso::generate_package_list() {
  local output_file="$1"
  local os_name="$2"

  # Get configuration values
  local runtime_type
  runtime_type=$(config::get_runtime_type 2>/dev/null || echo "containerd")

  local network_plugin
  network_plugin=$(config::get_network_plugin 2>/dev/null || echo "calico")

  local lb_enabled
  lb_enabled=$(config::get_loadbalancer_enabled 2>/dev/null || echo "false")

  local lb_type
  lb_type=$(config::get_loadbalancer_type 2>/dev/null || echo "none")

  # Check if storage is enabled
  local storage_type
  storage_type=$(defaults::get_storage_type 2>/dev/null || echo "none")
  local has_storage="false"
  if [[ "${storage_type}" != "none" ]]; then
    has_storage="true"
  fi

  # Get system packages using the complete definition from defaults.sh
  local packages
  packages=$(defaults::get_system_packages "${os_name}" "${runtime_type}" "${network_plugin}" "${lb_type}" "${has_storage}" "${lb_enabled}")

  echo "# System Packages for Docker Build" > "${output_file}"
  echo "# Generated: $(date)" >> "${output_file}"
  echo "# OS: ${os_name}" >> "${output_file}"
  echo "# Runtime: ${runtime_type}" >> "${output_file}"
  echo "# CNI: ${network_plugin}" >> "${output_file}"
  echo "# LoadBalancer: ${lb_type} (enabled: ${lb_enabled})" >> "${output_file}"
  echo "# Storage: ${storage_type} (enabled: ${has_storage})" >> "${output_file}"
  echo "" >> "${output_file}"

  # Write package list
  echo "${packages}" >> "${output_file}"

  log::info "Package list generated for ${os_name}: ${output_file}"
  log::info "  Total packages: $(echo "${packages}" | wc -l)"
  log::info "  Storage enabled: ${storage_type} (${has_storage})"
}

# Download system packages using Docker containers
system_iso::download_packages_in_docker() {
  local os_name="$1"
  local temp_dir="$2"
  local arch="${3:-$(defaults::get_arch)}"
  local pkg_file="${4:-}"

  log::info "Downloading system packages for ${os_name} in Docker container"
  log::info "  Architecture: ${arch}"

  # Use pre-resolved package list if provided, otherwise generate
  local package_list
  if [[ -n "${pkg_file}" && -f "${pkg_file}" ]]; then
    package_list="${pkg_file}"
    log::info "  Using pre-resolved package list: ${package_list}"
  else
    package_list="${temp_dir}/packages.txt"
    system_iso::generate_package_list "${package_list}" "${os_name}"
  fi

  # Determine output directory
  local output_dir="${temp_dir}/packages/${os_name}"
  mkdir -p "${output_dir}"

  # Use docker-based builder to download packages
  packages::build_with_docker "${os_name}" "${package_list}" "${output_dir}" "${arch}" || {
    log::error "Failed to download packages for ${os_name}"
    return 1
  }

  log::info "System packages downloaded for ${os_name}"
  return 0
}

# Detect local OS name in system ISO list
system_iso::detect_local_os_name() {
  if [[ ! -f /etc/os-release ]]; then
    log::error "Cannot detect OS: /etc/os-release not found"
    return 1
  fi

  source /etc/os-release
  local id="${ID}"
  local version="${VERSION_ID}"
  local major="${version%%.*}"

  case "${id}" in
    centos|rhel)
      if [[ "${major}" -ge 8 ]]; then
        echo "centos8"
      else
        echo "centos7"
      fi
      ;;
    rocky)
      if [[ "${major}" -ge 9 ]]; then
        echo "rocky9"
      else
        echo "rocky8"
      fi
      ;;
    almalinux)
      if [[ "${major}" -ge 9 ]]; then
        echo "almalinux9"
      else
        echo "almalinux8"
      fi
      ;;
    ubuntu)
      if [[ "${major}" -ge 22 ]]; then
        echo "ubuntu22"
      else
        echo "ubuntu20"
      fi
      ;;
    debian)
      if [[ "${major}" -ge 12 ]]; then
        echo "debian12"
      else
        echo "debian11"
      fi
      ;;
    uos)
      echo "uos20"
      ;;
    kylin)
      echo "kylin10"
      ;;
    openeuler)
      echo "openeuler22"
      ;;
    *)
      log::error "Unsupported OS: ${id}"
      return 1
      ;;
  esac
}

# Download system packages locally (no Docker)
system_iso::download_packages_local() {
  local os_name="$1"
  local temp_dir="$2"
  local arch="${3:-$(uname -m)}"
  local pkg_file="${4:-}"

  log::info "Downloading system packages locally for ${os_name}"
  log::info "  Architecture: ${arch}"

  # Use pre-resolved package list if provided, otherwise generate
  local package_list
  if [[ -n "${pkg_file}" && -f "${pkg_file}" ]]; then
    package_list="${pkg_file}"
    log::info "  Using pre-resolved package list: ${package_list}"
  else
    package_list="${temp_dir}/packages.txt"
    system_iso::generate_package_list "${package_list}" "${os_name}"
  fi

  local output_dir="${temp_dir}/packages/${os_name}"
  mkdir -p "${output_dir}"

  packages::build_direct "${package_list}" "${output_dir}" "${arch}" || {
    log::error "Failed to download packages locally for ${os_name}"
    return 1
  }

  log::info "System packages downloaded locally for ${os_name}"
}

# Generate repository configuration for each OS
system_iso::generate_repo_config() {
  local os_name="$1"
  local iso_root="$2"

  log::info "Generating repository configuration for ${os_name}"

  case "${os_name}" in
    centos*|rocky*|almalinux*|rhel*|ol*|anolis*|fedora*|kylin*|openeuler*|uos*)
      # RPM-based: create yum.repos.d file
      cat > "${iso_root}/${os_name}/repo/kubexm-system-packages.repo" << EOF
[kubexm-system-packages]
name=KubeXM System Packages - ${os_name}
baseurl=file://\${PWD}/../packages
enabled=1
gpgcheck=0
priority=1
EOF
      ;;
    ubuntu*|debian*)
      # DEB-based: create sources.list file
      cat > "${iso_root}/${os_name}/repo/kubexm-system-packages.list" << EOF
deb [trusted=yes] file://\${PWD}/../packages ./
EOF
      ;;
  esac

  log::info "Repository configuration generated for ${os_name}"
}

# Generate installation script
system_iso::generate_install_script() {
  local iso_root="$1"

  log::info "Generating system packages installation script"

  cat > "${iso_root}/install/install-system-packages.sh" << 'EOF'
#!/bin/bash
# KubeXM System Packages Installation Script

set -euo pipefail

# Detect OS
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  OS_ID="${ID}"
else
  echo "Error: Cannot detect OS"
  exit 1
fi

# Find matching OS directory
OS_DIR=""
for dir in centos* rhel* rocky* ol* almalinux* anolis* fedora* kylin* openeuler* uos* ubuntu* debian*; do
  [[ -d "${dir}" ]] || continue
  case "${OS_ID}" in
    centos)
      [[ "${dir}" == "centos"* ]] && OS_DIR="${dir}" && break
      ;;
    rhel)
      [[ "${dir}" == "rhel"* ]] && OS_DIR="${dir}" && break
      ;;
    rocky)
      [[ "${dir}" == "rocky"* ]] && OS_DIR="${dir}" && break
      ;;
    ol|oracle)
      [[ "${dir}" == "ol"* ]] && OS_DIR="${dir}" && break
      ;;
    almalinux)
      [[ "${dir}" == "almalinux"* ]] && OS_DIR="${dir}" && break
      ;;
    anolis)
      [[ "${dir}" == "anolis"* ]] && OS_DIR="${dir}" && break
      ;;
    fedora)
      [[ "${dir}" == "fedora"* ]] && OS_DIR="${dir}" && break
      ;;
    kylin)
      [[ "${dir}" == "kylin"* ]] && OS_DIR="${dir}" && break
      ;;
    openeuler)
      [[ "${dir}" == "openeuler"* ]] && OS_DIR="${dir}" && break
      ;;
    uos)
      [[ "${dir}" == "uos"* ]] && OS_DIR="${dir}" && break
      ;;
    ubuntu)
      [[ "${dir}" == "ubuntu"* ]] && OS_DIR="${dir}" && break
      ;;
    debian)
      [[ "${dir}" == "debian"* ]] && OS_DIR="${dir}" && break
      ;;
  esac
done

if [[ -z "${OS_DIR}" ]]; then
  echo "Error: No matching OS directory found"
  exit 1
fi

echo "Detected OS: ${OS_ID}, using packages from: ${OS_DIR}"

# Install packages
cd "${OS_DIR}"

case "${OS_ID}" in
  centos|rhel|rocky|ol|almalinux|anolis|fedora|kylin|openeuler|uos)
    # RPM-based (all use yum/dnf)
    yum install -y packages/*.rpm || dnf install -y packages/*.rpm
    ;;
  ubuntu|debian)
    # DEB-based
    apt-get update
    apt-get install -y packages/*.deb
    ;;
esac

echo "System packages installed successfully"
EOF

  chmod +x "${iso_root}/install/install-system-packages.sh"

  log::info "Installation script generated"
}

# Generate README for system packages ISO
system_iso::generate_readme() {
  local iso_root="$1"

  log::info "Generating README"

  cat > "${iso_root}/README.txt" << 'EOF'
KubeXM System Packages ISO
===========================

This ISO contains system dependency packages for Kubernetes deployment.

Contents:
- System packages: haproxy, nginx, keepalived, conntrack, socat, ethtool
- For 26 OS: CentOS, Rocky, AlmaLinux, RHEL, Oracle Linux, Anolis, Fedora,
  Kylin, openEuler, UOS, Ubuntu, Debian
- Local package repositories
- Installation scripts

Installation:
1. Mount this ISO: mount -o loop kubexm-system-packages.iso /mnt
2. Run installation: /mnt/install/install-system-packages.sh
3. Follow the prompts

OS Support:
- CentOS 7/8
- Rocky Linux 8/9
- AlmaLinux 8/9
- RHEL 7/8/9
- Oracle Linux 8/9
- Anolis 8/9
- Fedora 39/40/41/42
- Kylin 10
- openEuler 22
- UOS 20
- Ubuntu 20.04/22.04/24.04
- Debian 10/11/12

Package List:
- haproxy: Load balancer
- nginx: Web server/load balancer
- keepalived: High availability
- conntrack: Connection tracking
- socat: Socket cat
- ethtool: Network interface tool

EOF

  log::info "README generated"
}

# -----------------------------------------------------------------------------
# ISO Generation
# -----------------------------------------------------------------------------

# Generate system packages ISO
system_iso::generate() {
  local iso_root="$1"
  local output_iso="$2"
  local iso_label="${3:-${DEFAULT_ISO_LABEL}}"

  log::info "Generating system packages ISO"
  log::info "  Source: ${iso_root}"
  log::info "  Output: ${output_iso}"
  log::info "  Label: ${iso_label}"

  # Check for ISO tool
  local iso_tool=""
  for tool in mkisofs genisoimage xorriso; do
    if command -v "${tool}" &>/dev/null; then
      iso_tool="${tool}"
      break
    fi
  done

  if [[ -z "${iso_tool}" ]]; then
    log::error "No ISO creation tool found"
    return 1
  fi

  log::info "Using ISO tool: ${iso_tool}"

  # Generate ISO
  case "${iso_tool}" in
    mkisofs|genisoimage)
      mkisofs -o "${output_iso}" \
        -V "${iso_label}" \
        -J -R -r \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        "${iso_root}"
      ;;
    xorriso)
      xorriso -as mkisofs \
        -o "${output_iso}" \
        -V "${iso_label}" \
        -J -R -r \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        "${iso_root}"
      ;;
  esac

  # Make ISO hybrid
  if command -v isohybrid &>/dev/null; then
    isohybrid "${output_iso}" 2>/dev/null || true
  fi

  # Generate checksum
  sha256sum "${output_iso}" > "${output_iso}.sha256"

  log::info "System packages ISO generated: ${output_iso}"
}

# -----------------------------------------------------------------------------
# Full Build Pipeline
# -----------------------------------------------------------------------------

# Build system packages ISO
system_iso::build() {
  local output_iso="$1"
  local os_list="${2:-centos7,rocky9,ubuntu22}"
  local arch="${3:-$(defaults::get_arch)}"
  local build_local="${4:-${KUBEXM_BUILD_LOCAL:-false}}"

  log::info "Building system packages ISO"
  log::info "  Output: ${output_iso}"
  log::info "  OS List: ${os_list}"
  log::info "  Architecture: ${arch}"
  if [[ "${build_local}" == "true" ]]; then
    log::info "  Workflow: Local package manager → ISO generation"
  else
    log::info "  Workflow: Docker containers → Package download → ISO generation"
  fi

  # Create temporary directory
  local temp_dir
  temp_dir=$(mktemp -d)
  trap "rm -rf ${temp_dir}" EXIT

  local iso_root="${temp_dir}/iso"
  mkdir -p "${iso_root}"

  # Create structure
  system_iso::create_structure "${iso_root}"

  # Process each OS in Docker containers
  IFS=',' read -ra os_array <<< "${os_list}"
  if [[ "${build_local}" == "true" ]]; then
    local local_os
    local_os="$(system_iso::detect_local_os_name)" || return 1
    os_array=("${local_os}")
    log::warn "build-local only supports current OS (${local_os}); other OS entries will be skipped"
  fi

  for os in "${os_array[@]}"; do
    log::info "Processing OS: ${os}"

    # Download packages
    if [[ "${build_local}" == "true" ]]; then
      system_iso::download_packages_local "${os}" "${temp_dir}" || {
        log::error "Failed to download packages for ${os}, skipping"
        continue
      }
    else
      system_iso::download_packages_in_docker "${os}" "${temp_dir}" "${arch}" || {
        log::error "Failed to download packages for ${os}, skipping"
        continue
      }
    fi

    # Copy downloaded packages to ISO structure
    if [[ -d "${temp_dir}/packages/${os}" ]]; then
      cp -r "${temp_dir}/packages/${os}/"* "${iso_root}/${os}/packages/" 2>/dev/null || true
      log::info "  Copied packages for ${os}"
    else
      log::warn "  No packages found for ${os}"
    fi

    # Generate repo config
    system_iso::generate_repo_config "${os}" "${iso_root}"
  done

  # Generate install script and README
  system_iso::generate_install_script "${iso_root}"
  system_iso::generate_readme "${iso_root}"

  # Generate ISO
  system_iso::generate "${iso_root}" "${output_iso}"

  log::info "System packages ISO build complete"
}

# -----------------------------------------------------------------------------
# Build per-OS ISOs (new structure)
# -----------------------------------------------------------------------------

# Parse OS name and version from OS identifier (e.g., "rocky9" -> "rocky", "9")
system_iso::parse_os() {
  local os_id="$1"
  case "${os_id}" in
    centos7)       echo "centos" "7" ;;
    centos8)       echo "centos" "8" ;;
    rocky8)        echo "rocky" "8" ;;
    rocky9)        echo "rocky" "9" ;;
    almalinux8)    echo "almalinux" "8" ;;
    almalinux9)    echo "almalinux" "9" ;;
    ubuntu20)      echo "ubuntu" "20.04" ;;
    ubuntu22)      echo "ubuntu" "22.04" ;;
    ubuntu24)      echo "ubuntu" "24.04" ;;
    debian10)      echo "debian" "10" ;;
    debian11)      echo "debian" "11" ;;
    debian12)      echo "debian" "12" ;;
    uos20)         echo "uos" "20" ;;
    kylin10)       echo "kylin" "10" ;;
    openeuler22)   echo "openeuler" "22" ;;
    rhel7)         echo "rhel" "7" ;;
    rhel8)         echo "rhel" "8" ;;
    rhel9)         echo "rhel" "9" ;;
    ol8)           echo "ol" "8" ;;
    ol9)           echo "ol" "9" ;;
    anolis8)       echo "anolis" "8" ;;
    anolis9)       echo "anolis" "9" ;;
    fedora39)      echo "fedora" "39" ;;
    fedora40)      echo "fedora" "40" ;;
    fedora41)      echo "fedora" "41" ;;
    fedora42)      echo "fedora" "42" ;;
    *)             echo "${os_id}" "" ;;
  esac
}

# Build one ISO per OS at the path structure:
# ${base_dir}/${os_name}/${os_version}/${arch}/${os_name}-${os_version}-${arch}.iso
system_iso::build_per_os() {
  local base_dir="${1:?Base directory required}"
  local os_list="${2:-centos7,rocky9,ubuntu22}"
  local arch="${3:-$(defaults::get_arch)}"
  local build_local="${4:-${KUBEXM_BUILD_LOCAL:-false}}"
  local checkpoint_dir="${5:-}"

  log::info "Building per-OS system packages ISOs"
  log::info "  Base directory: ${base_dir}"
  log::info "  OS List: ${os_list}"
  log::info "  Architecture: ${arch}"
  log::info "  Checkpoint dir: ${checkpoint_dir:-none (will resolve packages inline)}"

  IFS=',' read -ra os_array <<< "${os_list}"

  local success_count=0
  local fail_count=0

  for os in "${os_array[@]}"; do
    log::info "Processing OS: ${os}"

    # Parse OS name and version
    local os_name os_version
    read -r os_name os_version <<< "$(system_iso::parse_os "${os}")"

    if [[ -z "${os_name}" ]]; then
      log::error "Unknown OS: ${os}, skipping"
      ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      continue
    fi

    # Build output path: ${base_dir}/${os_name}/${os_version}/${arch}/${os_name}-${os_version}-${arch}.iso
    local output_dir="${base_dir}/${os_name}/${os_version}/${arch}"
    local output_iso="${output_dir}/${os_name}-${os_version}-${arch}.iso"

    log::info "  Output ISO: ${output_iso}"

    # Create temp directory for this OS
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '${temp_dir}'" RETURN

    local iso_root="${temp_dir}/iso"
    mkdir -p "${iso_root}"

    # Create structure for this OS only
    system_iso::create_structure_for_os "${iso_root}" "${os}" || {
      log::error "Failed to create structure for ${os}"
      rm -rf "${temp_dir}"
      ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      continue
    }

    # Use checkpoint package list if available, otherwise resolve inline
    local pkg_file=""
    if [[ -n "${checkpoint_dir}" && -f "${checkpoint_dir}/packages-${os}.txt" ]]; then
      pkg_file="${checkpoint_dir}/packages-${os}.txt"
      log::info "  Using pre-resolved package list: ${pkg_file}"
    fi

    # Download packages (pass pkg_file if available)
    if [[ "${build_local}" == "true" ]]; then
      system_iso::download_packages_local "${os}" "${temp_dir}" "${arch}" "${pkg_file}" || {
        log::error "Failed to download packages for ${os}"
        rm -rf "${temp_dir}"
        ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
        continue
      }
    else
      system_iso::download_packages_in_docker "${os}" "${temp_dir}" "${arch}" "${pkg_file}" || {
        log::error "Failed to download packages for ${os}"
        rm -rf "${temp_dir}"
        ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
        continue
      }
    fi

    # Copy downloaded packages to ISO structure
    if [[ -d "${temp_dir}/packages/${os}" ]]; then
      mkdir -p "${iso_root}/${os}/packages"
      cp -r "${temp_dir}/packages/${os}/"* "${iso_root}/${os}/packages/" 2>/dev/null || true
    fi

    # Generate repo config for this OS
    system_iso::generate_repo_config "${os}" "${iso_root}"

    # Create install directory and script
    mkdir -p "${iso_root}/install"

    # Generate ISO
    mkdir -p "${output_dir}"
    system_iso::generate "${iso_root}" "${output_iso}"

    # Cleanup temp
    rm -rf "${temp_dir}"

    if [[ -f "${output_iso}" ]]; then
      log::success "  ✓ ${os} ISO built: ${output_iso}"
      ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      log::error "  ✗ ${os} ISO build failed"
      ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  done

  log::info "Per-OS ISO build complete: ${success_count} succeeded, ${fail_count} failed"
  if [[ ${fail_count} -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Create directory structure for a single OS (helper for build_per_os)
system_iso::create_structure_for_os() {
  local iso_root="$1"
  local os="$2"

  mkdir -p "${iso_root}/${os}/"{packages,repo}
  mkdir -p "${iso_root}/install"
  return 0
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
system_iso::main() {
  local action="${1:-}"
  shift || true

  case "${action}" in
    build)
      local output_iso="${1:?Output ISO file required}"
      local os_list="${2:-centos7,rocky9,ubuntu22}"
      local arch="${3:-$(defaults::get_arch)}"
      system_iso::build "${output_iso}" "${os_list}" "${arch}"
      ;;
    help|--help|-h)
      cat << 'EOF'
KubeXM System Packages ISO Builder

Usage: build-system-packages-iso.sh <action> [options]

Actions:
  build <output> [os_list] [arch]    Build system packages ISO

Examples:
  # Build ISO for default OS and architecture
  build-system-packages-iso.sh build /output/kubexm-system-packages.iso

  # Build ISO for specific OS
  build-system-packages-iso.sh build /output/pkgs.iso "centos7,rocky9,ubuntu22"

  # Build ISO for specific OS and architecture
  build-system-packages-iso.sh build /output/pkgs.iso "centos7,rocky9" "amd64"

Workflow:
  1. Build Docker images for each OS
  2. Run Docker containers to download packages (with dependencies)
  3. Copy packages to ISO structure
  4. Generate ISO file

This creates an ISO containing complete system dependency packages:
- Base tools: curl, wget, jq, vim, git, tar, gzip, unzip, expect, sshpass, bash-completion
- Network: conntrack-tools, ebtables, ethtool, iproute2, iptables, ipvsadm, socat
- System: chrony, rsync, htop
- LoadBalancer (when enabled): haproxy, nginx, keepalived
- Storage (when enabled): nfs-utils/nfs-common, iscsi-initiator-utils/open-iscsi
- For multiple OS types (CentOS, Rocky, AlmaLinux, Ubuntu, Debian, UOS, Kylin, openEuler)
- Packages downloaded in Docker containers (with all dependencies)
- Dynamically generated based on configuration (runtime, CNI, loadbalancer)
- With local package repositories
- Installation scripts included
EOF
      ;;
    *)
      echo "Unknown action: ${action}"
      echo "Use 'build-system-packages-iso.sh help' for usage"
      return 1
      ;;
  esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  system_iso::main "$@"
fi
