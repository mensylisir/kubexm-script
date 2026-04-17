#!/bin/bash
# =============================================================================
# KubeXM Script - ISO Build and Generation
# =============================================================================
# Purpose: Generate bootable ISO images for offline Kubernetes deployment
# Supports BIOS and UEFI boot modes, multiple architectures
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
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
ISO_TEMPLATE_DIR="${KUBEXM_SCRIPT_ROOT}/templates/build/iso"
DEFAULT_ISO_LABEL="KUBEXM"
DEFAULT_ISO_VERSION="1.0.0"

# ISO directory structure
declare -a ISO_DIRS=(
  "isolinux"
  "EFI/BOOT"
  "packages/system"
  "packages/kubernetes"
  "kubernetes/bin"
  "kubernetes/images"
  "kubernetes/manifests"
  "kubernetes/charts"
  "install"
  "config"
  "docs"
)

# -----------------------------------------------------------------------------
# ISO Structure Functions
# -----------------------------------------------------------------------------

# Create ISO directory structure
iso::create_structure() {
  local iso_root="$1"

  log::info "Creating ISO directory structure: ${iso_root}"

  for dir in "${ISO_DIRS[@]}"; do
    mkdir -p "${iso_root}/${dir}"
  done

  log::info "Directory structure created"
}

# Copy Kubernetes binaries
iso::copy_kubernetes_binaries() {
  local iso_root="$1"
  local k8s_dir="$2"
  local arch="${3:-$(defaults::get_arch)}"

  log::info "Copying Kubernetes binaries"
  log::info "  Source: ${k8s_dir}"
  log::info "  Architecture: ${arch}"

  local target_dir="${iso_root}/kubernetes/bin/${arch}"
  mkdir -p "${target_dir}"

  # List of expected binaries
  local binaries=(
    "kubectl"
    "kubeadm"
    "kubelet"
    "crictl"
    "ctr"
    "containerd"
    "containerd-shim"
    "containerd-shim-runc-v2"
    "runc"
  )

  local copied=0
  for binary in "${binaries[@]}"; do
    if [[ -f "${k8s_dir}/${binary}" ]]; then
      cp "${k8s_dir}/${binary}" "${target_dir}/"
      chmod +x "${target_dir}/${binary}"
      ((copied++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      log::debug "  Binary not found: ${binary}"
    fi
  done

  log::info "Copied ${copied} binaries"
}

# Copy container images
iso::copy_container_images() {
  local iso_root="$1"
  local images_dir="$2"

  log::info "Copying container images"
  log::info "  Source: ${images_dir}"

  local target_dir="${iso_root}/kubernetes/images"

  if [[ -d "${images_dir}" ]]; then
    cp -r "${images_dir}"/* "${target_dir}/" 2>/dev/null || true
    local count
    count=$(find "${target_dir}" -name "*.tar" -o -name "*.tar.gz" | wc -l)
    log::info "Copied ${count} image files"
  else
    log::warn "Images directory not found: ${images_dir}"
  fi
}

# Copy system packages
iso::copy_system_packages() {
  local iso_root="$1"
  local packages_dir="$2"

  log::info "Copying system packages"
  log::info "  Source: ${packages_dir}"

  local target_dir="${iso_root}/packages/system"

  if [[ -d "${packages_dir}" ]]; then
    cp -r "${packages_dir}"/* "${target_dir}/" 2>/dev/null || true
    local count
    count=$(find "${target_dir}" \( -name "*.rpm" -o -name "*.deb" \) | wc -l)
    log::info "Copied ${count} package files"
  else
    log::warn "Packages directory not found: ${packages_dir}"
  fi
}

# Copy Helm charts
iso::copy_helm_charts() {
  local iso_root="$1"
  local charts_dir="$2"

  log::info "Copying Helm charts"

  local target_dir="${iso_root}/kubernetes/charts"

  if [[ -d "${charts_dir}" ]]; then
    cp -r "${charts_dir}"/* "${target_dir}/" 2>/dev/null || true
    local count
    count=$(find "${target_dir}" -name "*.tgz" | wc -l)
    log::info "Copied ${count} chart files"
  else
    log::debug "Charts directory not found: ${charts_dir}"
  fi
}

# Copy configuration files
iso::copy_config() {
  local iso_root="$1"
  local config_file="$2"

  log::info "Copying configuration"

  local target_dir="${iso_root}/config"

  if [[ -f "${config_file}" ]]; then
    cp "${config_file}" "${target_dir}/cluster.yaml"
    log::info "Copied cluster configuration"
  fi

  # Copy install scripts
  if [[ -f "${KUBEXM_ROOT}/templates/install/install.sh" ]]; then
    cp "${KUBEXM_ROOT}/templates/install/install.sh" "${iso_root}/install/"
    chmod +x "${iso_root}/install/install.sh"
  fi
}

# -----------------------------------------------------------------------------
# Boot Configuration Functions
# -----------------------------------------------------------------------------

# Generate isolinux.cfg for BIOS boot
iso::generate_isolinux_cfg() {
  local iso_root="$1"
  local iso_label="${2:-${DEFAULT_ISO_LABEL}}"

  log::info "Generating isolinux.cfg"

  cat > "${iso_root}/isolinux/isolinux.cfg" << EOF
# KubeXM Offline Installer - BIOS Boot Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

DEFAULT menu.c32
PROMPT 0
TIMEOUT 600
ONTIMEOUT install

MENU TITLE KubeXM Kubernetes Installer
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std

LABEL install
    MENU LABEL ^1. Install KubeXM Kubernetes Cluster
    MENU DEFAULT
    KERNEL vmlinuz
    APPEND initrd=initrd.img inst.stage2=hd:LABEL=${iso_label} quiet

LABEL shell
    MENU LABEL ^2. Start Shell for Manual Installation
    KERNEL vmlinuz
    APPEND initrd=initrd.img inst.stage2=hd:LABEL=${iso_label} inst.shell

LABEL rescue
    MENU LABEL ^3. Rescue Mode
    KERNEL vmlinuz
    APPEND initrd=initrd.img inst.stage2=hd:LABEL=${iso_label} rescue

LABEL local
    MENU LABEL ^4. Boot from Local Drive
    LOCALBOOT 0
EOF

  log::info "isolinux.cfg generated"
}

# Generate grub.cfg for UEFI boot
iso::generate_grub_cfg() {
  local iso_root="$1"
  local iso_label="${2:-${DEFAULT_ISO_LABEL}}"

  log::info "Generating grub.cfg for UEFI"

  cat > "${iso_root}/EFI/BOOT/grub.cfg" << EOF
# KubeXM Offline Installer - UEFI Boot Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

set default="0"
set timeout=60

menuentry "Install KubeXM Kubernetes Cluster" --class os {
    set gfxpayload=keep
    linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=${iso_label} quiet
    initrdefi /images/pxeboot/initrd.img
}

menuentry "Install KubeXM (Text Mode)" --class os {
    linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=${iso_label} inst.text
    initrdefi /images/pxeboot/initrd.img
}

menuentry "Rescue Mode" --class os {
    linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=${iso_label} rescue
    initrdefi /images/pxeboot/initrd.img
}

menuentry "Boot from Local Drive" --class os {
    set root=(hd0)
    chainloader +1
}
EOF

  log::info "grub.cfg generated"
}

# -----------------------------------------------------------------------------
# Installation Script Functions
# -----------------------------------------------------------------------------

# Generate autorun install script
iso::generate_install_script() {
  local iso_root="$1"
  local os_type="${2:-$(defaults::get_os_type)}"

  log::info "Generating installation scripts"

  cat > "${iso_root}/install/autorun.sh" << 'EOF'
#!/bin/bash
# =============================================================================
# KubeXM Automatic Installation Script
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source functions
source "${ISO_ROOT}/install/functions.sh"

# Main installation
main() {
  log::info "Starting KubeXM installation"

  # Detect OS
  detect_os

  # Mount and configure local repository
  configure_local_repo

  # Install system packages
  install_system_packages

  # Install Kubernetes binaries
  install_kubernetes_binaries

  # Load container images
  load_container_images

  # Configure system
  configure_system

  # Initialize cluster (if master)
  initialize_cluster

  log::info "Installation complete!"
}

main "$@"
EOF

  chmod +x "${iso_root}/install/autorun.sh"

  # Generate functions library
  cat > "${iso_root}/install/functions.sh" << 'FUNCTIONS_EOF'
#!/bin/bash
# KubeXM Installation Functions

# Logging
log::info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
log::warn() { echo "[WARN] $(date '+%H:%M:%S') $*" >&2; }
log::error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }

# OS Detection
detect_os() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_ID="${ID}"
    OS_VERSION="${VERSION_ID}"
    log::info "Detected OS: ${OS_ID} ${OS_VERSION}"
  else
    log::error "Cannot detect OS"
    exit 1
  fi

  case "${OS_ID}" in
    centos|rhel|rocky|almalinux|fedora|kylin|openeuler)
      PKG_MANAGER="yum"
      PKG_TYPE="rpm"
      ;;
    ubuntu|debian|uos)
      PKG_MANAGER="apt"
      PKG_TYPE="deb"
      ;;
    *)
      log::error "Unsupported OS: ${OS_ID}"
      exit 1
      ;;
  esac
}

# Configure local repository
configure_local_repo() {
  local pkg_dir="${ISO_ROOT}/packages/system"

  log::info "Configuring local package repository"

  case "${PKG_TYPE}" in
    rpm)
      cat > /etc/yum.repos.d/kubexm-local.repo << EOF
[kubexm-local]
name=KubeXM Local Repository
baseurl=file://${pkg_dir}
enabled=1
gpgcheck=0
priority=1
EOF
      yum clean all
      ;;
    deb)
      echo "deb [trusted=yes] file://${pkg_dir} ./" > /etc/apt/sources.list.d/kubexm-local.list
      apt-get update
      ;;
  esac

  log::info "Local repository configured"
}

# Install system packages
install_system_packages() {
  log::info "Installing system packages"

  local packages=(
    "curl" "wget" "conntrack" "socat" "ipvsadm"
  )

  # Check for LoadBalancer packages
  if [[ -f "${ISO_ROOT}/config/cluster.yaml" ]]; then
    # Parse config to determine LB type
    if grep -q "loadbalancer.*haproxy" "${ISO_ROOT}/config/cluster.yaml" 2>/dev/null; then
      packages+=("haproxy" "keepalived")
    elif grep -q "loadbalancer.*nginx" "${ISO_ROOT}/config/cluster.yaml" 2>/dev/null; then
      packages+=("nginx" "keepalived")
    fi
  fi

  case "${PKG_MANAGER}" in
    yum) yum install -y "${packages[@]}" ;;
    apt) apt-get install -y "${packages[@]}" ;;
  esac

  log::info "System packages installed"
}

# Install Kubernetes binaries
install_kubernetes_binaries() {
  local arch
  arch=$(uname -m)
  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
  esac

  local bin_dir="${ISO_ROOT}/kubernetes/bin/${arch}"

  log::info "Installing Kubernetes binaries from ${bin_dir}"

  if [[ -d "${bin_dir}" ]]; then
    for binary in "${bin_dir}"/*; do
      if [[ -f "${binary}" ]]; then
        install -m 755 "${binary}" /usr/local/bin/
        log::info "  Installed: $(basename "${binary}")"
      fi
    done
  else
    log::warn "Binary directory not found: ${bin_dir}"
  fi
}

# Load container images
load_container_images() {
  local images_dir="${ISO_ROOT}/kubernetes/images"

  log::info "Loading container images"

  if [[ ! -d "${images_dir}" ]]; then
    log::warn "Images directory not found"
    return
  fi

  # Determine container runtime
  local runtime=""
  if command -v ctr &>/dev/null; then
    runtime="containerd"
  elif command -v docker &>/dev/null; then
    runtime="docker"
  else
    log::warn "No container runtime found"
    return
  fi

  for image_file in "${images_dir}"/*.tar "${images_dir}"/*.tar.gz; do
    [[ -f "${image_file}" ]] || continue

    log::info "  Loading: $(basename "${image_file}")"

    case "${runtime}" in
      containerd)
        ctr -n k8s.io images import "${image_file}" 2>/dev/null || true
        ;;
      docker)
        docker load -i "${image_file}" 2>/dev/null || true
        ;;
    esac
  done

  log::info "Container images loaded"
}

# Configure system
configure_system() {
  log::info "Configuring system"

  # Disable swap
  swapoff -a
  sed -i '/swap/d' /etc/fstab

  # Load kernel modules
  cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

  modprobe overlay 2>/dev/null || true
  modprobe br_netfilter 2>/dev/null || true

  # Sysctl settings
  cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

  sysctl --system

  log::info "System configured"
}

# Initialize cluster
initialize_cluster() {
  log::info "Cluster initialization - see documentation for next steps"
  log::info "Run: kubeadm init --config=/path/to/config.yaml"
}
FUNCTIONS_EOF

  chmod +x "${iso_root}/install/functions.sh"

  log::info "Installation scripts generated"
}

# -----------------------------------------------------------------------------
# ISO Generation Functions
# -----------------------------------------------------------------------------

# Check required tools
iso::check_tools() {
  local tools=("mkisofs" "genisoimage" "xorriso")
  local found=""

  for tool in "${tools[@]}"; do
    if command -v "${tool}" &>/dev/null; then
      found="${tool}"
      break
    fi
  done

  if [[ -z "${found}" ]]; then
    log::error "No ISO creation tool found. Install one of: ${tools[*]}"
    return 1
  fi

  log::info "Using ISO tool: ${found}"
  echo "${found}"
}

# Generate ISO file
iso::generate() {
  local iso_root="$1"
  local output_iso="$2"
  local iso_label="${3:-${DEFAULT_ISO_LABEL}}"

  log::info "Generating ISO image"
  log::info "  Source: ${iso_root}"
  log::info "  Output: ${output_iso}"
  log::info "  Label: ${iso_label}"

  # Check for ISO tool
  local iso_tool
  iso_tool=$(iso::check_tools) || return 1

  local iso_args=()

  case "${iso_tool}" in
    mkisofs|genisoimage)
      iso_args=(
        "-o" "${output_iso}"
        "-V" "${iso_label}"
        "-J"                    # Joliet extensions
        "-R"                    # Rock Ridge extensions
        "-r"                    # Rationalized Rock Ridge
        "-T"                    # Generate TRANS.TBL
      )

      # BIOS boot
      if [[ -f "${iso_root}/isolinux/isolinux.bin" ]]; then
        iso_args+=(
          "-b" "isolinux/isolinux.bin"
          "-c" "isolinux/boot.cat"
          "-no-emul-boot"
          "-boot-load-size" "4"
          "-boot-info-table"
        )
      fi

      # UEFI boot
      if [[ -f "${iso_root}/EFI/BOOT/efiboot.img" ]]; then
        iso_args+=(
          "-eltorito-alt-boot"
          "-e" "EFI/BOOT/efiboot.img"
          "-no-emul-boot"
        )
      fi

      iso_args+=("${iso_root}")

      ${iso_tool} "${iso_args[@]}"
      ;;

    xorriso)
      iso_args=(
        "-as" "mkisofs"
        "-o" "${output_iso}"
        "-V" "${iso_label}"
        "-J" "-R" "-r"
      )

      if [[ -f "${iso_root}/isolinux/isolinux.bin" ]]; then
        iso_args+=(
          "-b" "isolinux/isolinux.bin"
          "-c" "isolinux/boot.cat"
          "-no-emul-boot"
          "-boot-load-size" "4"
          "-boot-info-table"
        )
      fi

      iso_args+=("${iso_root}")

      xorriso "${iso_args[@]}"
      ;;
  esac

  # Make ISO hybrid (bootable from USB)
  if command -v isohybrid &>/dev/null; then
    log::info "Making ISO hybrid (USB bootable)"
    isohybrid "${output_iso}" 2>/dev/null || true
  fi

  # Generate checksum
  local checksum_file="${output_iso}.sha256"
  sha256sum "${output_iso}" > "${checksum_file}"
  log::info "Checksum: ${checksum_file}"

  # Show ISO info
  local iso_size
  iso_size=$(du -h "${output_iso}" | cut -f1)
  log::info "ISO generated: ${output_iso} (${iso_size})"
}

# -----------------------------------------------------------------------------
# Full Build Pipeline
# -----------------------------------------------------------------------------

# Build complete ISO from resources
iso::build_full() {
  local output_iso="$1"
  local k8s_version="${2:-}"; k8s_version="${k8s_version:-${DEFAULT_KUBERNETES_VERSION:-v1.32.4}}"
  local resources_dir="${3:-${KUBEXM_SCRIPT_ROOT}/resources}"
  local config_file="${4:-}"
  local arch="${5:-$(defaults::get_arch)}"

  log::info "Building complete ISO"
  log::info "  Output: ${output_iso}"
  log::info "  K8s Version: ${k8s_version}"
  log::info "  Resources: ${resources_dir}"
  log::info "  Architecture: ${arch}"

  # Create temporary ISO root
  local iso_root
  iso_root=$(mktemp -d)
  trap "rm -rf ${iso_root}" EXIT

  # Create structure
  iso::create_structure "${iso_root}"

  # Copy resources
  iso::copy_kubernetes_binaries "${iso_root}" "${resources_dir}/kubernetes/${arch}" "${arch}"
  iso::copy_container_images "${iso_root}" "${resources_dir}/images"
  iso::copy_system_packages "${iso_root}" "${resources_dir}/packages"
  iso::copy_helm_charts "${iso_root}" "${resources_dir}/charts"

  if [[ -n "${config_file}" && -f "${config_file}" ]]; then
    iso::copy_config "${iso_root}" "${config_file}"
  fi

  # Generate boot configuration
  local iso_label="${DEFAULT_ISO_LABEL}-${k8s_version//./}"
  iso::generate_isolinux_cfg "${iso_root}" "${iso_label}"
  iso::generate_grub_cfg "${iso_root}" "${iso_label}"

  # Generate install scripts
  iso::generate_install_script "${iso_root}"

  # Generate README
  cat > "${iso_root}/README.txt" << EOF
KubeXM Kubernetes Offline Installer
====================================

Version: ${k8s_version}
Architecture: ${arch}
Generated: $(date '+%Y-%m-%d %H:%M:%S')

Contents:
- Kubernetes binaries (kubectl, kubeadm, kubelet)
- Container runtime (containerd)
- Container images (control plane, CNI, etc.)
- System packages (haproxy, keepalived, etc.)
- Helm charts (optional addons)

Installation:
1. Boot from this ISO
2. Follow the on-screen instructions
3. Or run: /install/autorun.sh

Manual Installation:
1. Mount ISO: mount -o loop kubexm.iso /mnt
2. Run: /mnt/install/autorun.sh
3. Follow the documentation

Documentation: https://github.com/kubexm/kubexm-script

EOF

  # Generate ISO
  iso::generate "${iso_root}" "${output_iso}" "${iso_label}"

  log::info "ISO build complete: ${output_iso}"
}

# Build ISO for specific OS
iso::build_for_os() {
  local os_name="$1"
  local output_iso="$2"
  local k8s_version="${3:-}"; k8s_version="${k8s_version:-${DEFAULT_KUBERNETES_VERSION:-v1.32.4}}"
  local resources_base="${4:-${KUBEXM_SCRIPT_ROOT}/resources}"

  log::info "Building ISO for OS: ${os_name}"

  local resources_dir="${resources_base}/${os_name}"

  if [[ ! -d "${resources_dir}" ]]; then
    log::error "Resources not found for OS: ${os_name}"
    log::error "Expected: ${resources_dir}"
    return 1
  fi

  iso::build_full "${output_iso}" "${k8s_version}" "${resources_dir}"
}

# Build multi-arch ISO
iso::build_multiarch() {
  local output_iso="$1"
  local k8s_version="${2:-}"; k8s_version="${k8s_version:-${DEFAULT_KUBERNETES_VERSION:-v1.32.4}}"
  local resources_dir="${3:-${KUBEXM_SCRIPT_ROOT}/resources}"

  log::info "Building multi-architecture ISO"

  local iso_root
  iso_root=$(mktemp -d)
  trap "rm -rf ${iso_root}" EXIT

  iso::create_structure "${iso_root}"

  # Copy binaries for both architectures
  for arch in amd64 arm64; do
    iso::copy_kubernetes_binaries "${iso_root}" "${resources_dir}/kubernetes/${arch}" "${arch}"
  done

  # Copy other resources
  iso::copy_container_images "${iso_root}" "${resources_dir}/images"
  iso::copy_system_packages "${iso_root}" "${resources_dir}/packages"
  iso::copy_helm_charts "${iso_root}" "${resources_dir}/charts"

  # Generate boot config and scripts
  local iso_label="${DEFAULT_ISO_LABEL}-MULTIARCH"
  iso::generate_isolinux_cfg "${iso_root}" "${iso_label}"
  iso::generate_grub_cfg "${iso_root}" "${iso_label}"
  iso::generate_install_script "${iso_root}"

  # Generate ISO
  iso::generate "${iso_root}" "${output_iso}" "${iso_label}"
}

# -----------------------------------------------------------------------------
# Verification Functions
# -----------------------------------------------------------------------------

# Verify ISO contents
iso::verify() {
  local iso_file="$1"

  log::info "Verifying ISO: ${iso_file}"

  if [[ ! -f "${iso_file}" ]]; then
    log::error "ISO file not found: ${iso_file}"
    return 1
  fi

  # Check checksum if exists
  if [[ -f "${iso_file}.sha256" ]]; then
    if sha256sum -c "${iso_file}.sha256"; then
      log::info "Checksum verified"
    else
      log::error "Checksum verification failed"
      return 1
    fi
  fi

  # Mount and check contents
  local mount_point
  mount_point=$(mktemp -d)
  trap "umount ${mount_point} 2>/dev/null; rmdir ${mount_point}" EXIT

  if mount -o loop,ro "${iso_file}" "${mount_point}"; then
    log::info "ISO mounted successfully"

    # Check required directories
    local required_dirs=("kubernetes" "packages" "install")
    for dir in "${required_dirs[@]}"; do
      if [[ -d "${mount_point}/${dir}" ]]; then
        log::info "  ✓ ${dir}/ exists"
      else
        log::warn "  ✗ ${dir}/ missing"
      fi
    done

    # Count files
    local k8s_bins pkg_files
    k8s_bins=$(find "${mount_point}/kubernetes/bin" -type f 2>/dev/null | wc -l)
    pkg_files=$(find "${mount_point}/packages" -type f 2>/dev/null | wc -l)

    log::info "  Kubernetes binaries: ${k8s_bins}"
    log::info "  Package files: ${pkg_files}"

    umount "${mount_point}"
  else
    log::error "Failed to mount ISO"
    return 1
  fi

  log::info "Verification complete"
}

# List ISO contents
iso::list_contents() {
  local iso_file="$1"

  if ! command -v isoinfo &>/dev/null; then
    log::error "isoinfo not available"
    return 1
  fi

  isoinfo -l -i "${iso_file}"
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
iso::main() {
  local action="${1:-}"
  shift || true

  case "${action}" in
    create-structure)
      local iso_root="${1:?ISO root directory required}"
      iso::create_structure "${iso_root}"
      ;;
    generate)
      local iso_root="${1:?ISO root directory required}"
      local output_iso="${2:?Output ISO file required}"
      local iso_label="${3:-${DEFAULT_ISO_LABEL}}"
      iso::generate "${iso_root}" "${output_iso}" "${iso_label}"
      ;;
    build)
      local output_iso="${1:?Output ISO file required}"
      local k8s_version="${2:-}"; k8s_version="${k8s_version:-${DEFAULT_KUBERNETES_VERSION:-v1.32.4}}"
      local resources_dir="${3:-}"
      local config_file="${4:-}"
      local arch="${5:-$(defaults::get_arch)}"
      iso::build_full "${output_iso}" "${k8s_version}" "${resources_dir}" "${config_file}" "${arch}"
      ;;
    build-os)
      local os_name="${1:?OS name required}"
      local output_iso="${2:?Output ISO file required}"
      local k8s_version="${3:-}"; k8s_version="${k8s_version:-${DEFAULT_KUBERNETES_VERSION:-v1.32.4}}"
      iso::build_for_os "${os_name}" "${output_iso}" "${k8s_version}"
      ;;
    build-multiarch)
      local output_iso="${1:?Output ISO file required}"
      local k8s_version="${2:-}"; k8s_version="${k8s_version:-${DEFAULT_KUBERNETES_VERSION:-v1.32.4}}"
      local resources_dir="${3:-}"
      iso::build_multiarch "${output_iso}" "${k8s_version}" "${resources_dir}"
      ;;
    verify)
      local iso_file="${1:?ISO file required}"
      iso::verify "${iso_file}"
      ;;
    list)
      local iso_file="${1:?ISO file required}"
      iso::list_contents "${iso_file}"
      ;;
    help|--help|-h)
      cat << 'EOF'
KubeXM ISO Build and Generation

Usage: build-iso.sh <action> [options]

Actions:
  create-structure <iso_root>           Create ISO directory structure
  generate <iso_root> <output> [label]  Generate ISO from directory
  build <output> [version] [resources] [config] [arch]
                                        Build complete ISO
  build-os <os> <output> [version]      Build ISO for specific OS
  build-multiarch <output> [version]    Build multi-architecture ISO
  verify <iso_file>                     Verify ISO contents
  list <iso_file>                       List ISO contents
  help                                  Show this help

Examples:
  # Build ISO from resources
  build-iso.sh build /output/kubexm.iso ${DEFAULT_KUBERNETES_VERSION:-v1.32.4} /resources

  # Build for specific OS
  build-iso.sh build-os centos7 /output/kubexm-centos7.iso

  # Build multi-arch ISO
  build-iso.sh build-multiarch /output/kubexm-multiarch.iso ${DEFAULT_KUBERNETES_VERSION:-v1.32.4}

  # Verify ISO
  build-iso.sh verify /output/kubexm.iso

ISO Structure:
  /isolinux/         - BIOS boot files
  /EFI/BOOT/         - UEFI boot files
  /packages/system/  - System packages (RPM/DEB)
  /kubernetes/bin/   - Kubernetes binaries
  /kubernetes/images/- Container images
  /kubernetes/charts/- Helm charts
  /install/          - Installation scripts
  /config/           - Configuration files

Requirements:
  - mkisofs, genisoimage, or xorriso
  - isohybrid (optional, for USB boot)
EOF
      ;;
    *)
      log::error "Unknown action: ${action}"
      echo "Use 'build-iso.sh help' for usage information"
      return 1
      ;;
  esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  iso::main "$@"
fi
