#!/bin/bash
# =============================================================================
# KubeXM Script - Offline Installation
# =============================================================================
# Purpose: Install Kubernetes and dependencies from offline resources
# Supports 13 operating systems, automatic detection, and health checks
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Script Root Detection
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "${SCRIPT_DIR}/../../../../.." && pwd)}"

# Source required libraries if available
if [[ -f "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh" ]]; then
  source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
else
  # Fallback logging functions
  log::info() { echo "[INFO] $(date '+%H:%M:%S') $*"; }
  log::warn() { echo "[WARN] $(date '+%H:%M:%S') $*" >&2; }
  log::error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }
  log::debug() { [[ "${DEBUG:-false}" == "true" ]] && echo "[DEBUG] $(date '+%H:%M:%S') $*"; }
fi

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
INSTALL_LOG="/var/log/kubexm-install.log"
BACKUP_DIR="/var/backup/kubexm"
K8S_BIN_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"

# Package manager commands
declare -A PKG_INSTALL=(
  ["yum"]="yum install -y"
  ["dnf"]="dnf install -y"
  ["apt"]="apt-get install -y"
)

declare -A PKG_UPDATE=(
  ["yum"]="yum makecache"
  ["dnf"]="dnf makecache"
  ["apt"]="apt-get update"
)

# Required binaries
declare -a REQUIRED_BINS=(
  "kubectl"
  "kubeadm"
  "kubelet"
)

# Optional binaries
declare -a OPTIONAL_BINS=(
  "crictl"
  "ctr"
  "containerd"
  "runc"
  "helm"
)

# -----------------------------------------------------------------------------
# OS Detection
# -----------------------------------------------------------------------------

# Detect operating system
install::detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    log::error "Cannot detect OS: /etc/os-release not found"
    return 1
  fi

  source /etc/os-release

  OS_ID="${ID}"
  OS_VERSION="${VERSION_ID}"
  OS_NAME="${NAME}"

  log::info "Detected OS: ${OS_NAME} (${OS_ID} ${OS_VERSION})"

  # Determine package manager
  case "${OS_ID}" in
    centos|rhel)
      if [[ "${OS_VERSION%%.*}" -ge 8 ]]; then
        PKG_MANAGER="dnf"
      else
        PKG_MANAGER="yum"
      fi
      PKG_TYPE="rpm"
      ;;
    rocky|almalinux|fedora|openeuler)
      PKG_MANAGER="dnf"
      PKG_TYPE="rpm"
      ;;
    kylin)
      PKG_MANAGER="dnf"
      PKG_TYPE="rpm"
      ;;
    ubuntu|debian)
      PKG_MANAGER="apt"
      PKG_TYPE="deb"
      ;;
    uos)
      PKG_MANAGER="apt"
      PKG_TYPE="deb"
      ;;
    *)
      log::error "Unsupported OS: ${OS_ID}"
      return 1
      ;;
  esac

  log::info "Package manager: ${PKG_MANAGER}"
  log::info "Package type: ${PKG_TYPE}"

  export OS_ID OS_VERSION OS_NAME PKG_MANAGER PKG_TYPE
}

# Detect architecture
install::detect_arch() {
  local arch
  arch=$(uname -m)

  case "${arch}" in
    x86_64)
      ARCH="amd64"
      RPM_ARCH="x86_64"
      ;;
    aarch64)
      ARCH="arm64"
      RPM_ARCH="aarch64"
      ;;
    *)
      log::error "Unsupported architecture: ${arch}"
      return 1
      ;;
  esac

  log::info "Architecture: ${ARCH} (${arch})"
  export ARCH RPM_ARCH
}

# -----------------------------------------------------------------------------
# Resource Detection
# -----------------------------------------------------------------------------

# Find installation resources
install::find_resources() {
  local search_paths=(
    "/mnt/kubexm"
    "/media/kubexm"
    "/cdrom"
    "/mnt/cdrom"
    "${SCRIPT_DIR}/.."
    "${KUBEXM_SCRIPT_ROOT}/resources"
  )

  for path in "${search_paths[@]}"; do
    if [[ -d "${path}/packages" || -d "${path}/kubernetes" ]]; then
      RESOURCES_DIR="${path}"
      log::info "Found resources at: ${RESOURCES_DIR}"
      return 0
    fi
  done

  log::error "Installation resources not found"
  log::error "Searched paths: ${search_paths[*]}"
  return 1
}

# Mount ISO if provided
install::mount_iso() {
  local iso_file="${1:-}"
  local mount_point="${2:-/mnt/kubexm}"

  if [[ -z "${iso_file}" ]]; then
    return 0
  fi

  if [[ ! -f "${iso_file}" ]]; then
    log::error "ISO file not found: ${iso_file}"
    return 1
  fi

  log::info "Mounting ISO: ${iso_file}"

  mkdir -p "${mount_point}"

  if mount -o loop,ro "${iso_file}" "${mount_point}"; then
    log::info "ISO mounted at: ${mount_point}"
    RESOURCES_DIR="${mount_point}"
    ISO_MOUNTED="true"
    return 0
  else
    log::error "Failed to mount ISO"
    return 1
  fi
}

# Unmount ISO
install::unmount_iso() {
  if [[ "${ISO_MOUNTED:-false}" == "true" ]]; then
    log::info "Unmounting ISO"
    umount "${RESOURCES_DIR}" 2>/dev/null || true
    ISO_MOUNTED="false"
  fi
}

# -----------------------------------------------------------------------------
# Repository Configuration
# -----------------------------------------------------------------------------

# Configure local RPM repository
install::configure_rpm_repo() {
  local pkg_dir="$1"
  local repo_file="/etc/yum.repos.d/kubexm-local.repo"

  log::info "Configuring local RPM repository"

  # Backup existing repo files
  mkdir -p "${BACKUP_DIR}/yum.repos.d"
  cp /etc/yum.repos.d/*.repo "${BACKUP_DIR}/yum.repos.d/" 2>/dev/null || true

  # Create local repo config
  cat > "${repo_file}" << EOF
[kubexm-local]
name=KubeXM Local Repository
baseurl=file://${pkg_dir}
enabled=1
gpgcheck=0
priority=1
module_hotfixes=1
EOF

  # Disable other repos temporarily
  for repo in /etc/yum.repos.d/*.repo; do
    [[ "${repo}" == "${repo_file}" ]] && continue
    sed -i 's/^enabled=1/enabled=0/' "${repo}" 2>/dev/null || true
  done

  # Update cache
  ${PKG_MANAGER} clean all
  ${PKG_MANAGER} makecache

  log::info "RPM repository configured"
}

# Configure local DEB repository
install::configure_deb_repo() {
  local pkg_dir="$1"
  local sources_file="/etc/apt/sources.list.d/kubexm-local.list"

  log::info "Configuring local DEB repository"

  # Backup existing sources
  mkdir -p "${BACKUP_DIR}/apt"
  cp /etc/apt/sources.list "${BACKUP_DIR}/apt/" 2>/dev/null || true
  cp -r /etc/apt/sources.list.d "${BACKUP_DIR}/apt/" 2>/dev/null || true

  # Disable existing sources temporarily
  mv /etc/apt/sources.list /etc/apt/sources.list.disabled 2>/dev/null || true
  for f in /etc/apt/sources.list.d/*.list; do
    [[ "${f}" == "${sources_file}" ]] && continue
    mv "${f}" "${f}.disabled" 2>/dev/null || true
  done

  # Create local repo config
  cat > "${sources_file}" << EOF
deb [trusted=yes] file://${pkg_dir} ./
EOF

  # Update cache
  apt-get update

  log::info "DEB repository configured"
}

# Restore original repositories
install::restore_repos() {
  log::info "Restoring original repositories"

  case "${PKG_TYPE}" in
    rpm)
      if [[ -d "${BACKUP_DIR}/yum.repos.d" ]]; then
        cp "${BACKUP_DIR}/yum.repos.d"/*.repo /etc/yum.repos.d/ 2>/dev/null || true
        rm -f /etc/yum.repos.d/kubexm-local.repo
        ${PKG_MANAGER} clean all
      fi
      ;;
    deb)
      if [[ -f "${BACKUP_DIR}/apt/sources.list" ]]; then
        mv /etc/apt/sources.list.disabled /etc/apt/sources.list 2>/dev/null || true
        for f in /etc/apt/sources.list.d/*.disabled; do
          mv "${f}" "${f%.disabled}" 2>/dev/null || true
        done
        rm -f /etc/apt/sources.list.d/kubexm-local.list
        apt-get update 2>/dev/null || true
      fi
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Package Installation
# -----------------------------------------------------------------------------

# Install system packages
install::install_packages() {
  local pkg_dir="$1"

  log::info "Installing system packages from: ${pkg_dir}"

  if [[ ! -d "${pkg_dir}" ]]; then
    log::warn "Package directory not found: ${pkg_dir}"
    return 0
  fi

  # Configure local repository
  case "${PKG_TYPE}" in
    rpm) install::configure_rpm_repo "${pkg_dir}" ;;
    deb) install::configure_deb_repo "${pkg_dir}" ;;
  esac

  # Define packages to install
  local packages=(
    "curl"
    "conntrack"
    "socat"
    "ipvsadm"
  )

  # Check for LoadBalancer packages
  if [[ -f "${RESOURCES_DIR}/config/cluster.yaml" ]]; then
    if grep -q "haproxy" "${RESOURCES_DIR}/config/cluster.yaml" 2>/dev/null; then
      packages+=("haproxy" "keepalived")
    elif grep -q "nginx" "${RESOURCES_DIR}/config/cluster.yaml" 2>/dev/null; then
      packages+=("nginx" "keepalived")
    fi
  fi

  # Install packages
  local cmd="${PKG_INSTALL[${PKG_MANAGER}]}"

  for pkg in "${packages[@]}"; do
    log::info "  Installing: ${pkg}"
    if ${cmd} "${pkg}" >> "${INSTALL_LOG}" 2>&1; then
      log::info "    ✓ Installed"
    else
      log::warn "    ✗ Failed to install (may not be required)"
    fi
  done
}

# Install Kubernetes binaries
install::install_k8s_binaries() {
  local bin_dir="${RESOURCES_DIR}/kubernetes/bin/${ARCH}"

  log::info "Installing Kubernetes binaries from: ${bin_dir}"

  if [[ ! -d "${bin_dir}" ]]; then
    log::error "Kubernetes binaries not found: ${bin_dir}"
    return 1
  fi

  mkdir -p "${K8S_BIN_DIR}"

  # Install required binaries
  for binary in "${REQUIRED_BINS[@]}"; do
    if [[ -f "${bin_dir}/${binary}" ]]; then
      log::info "  Installing: ${binary}"
      install -m 755 "${bin_dir}/${binary}" "${K8S_BIN_DIR}/"
    else
      log::error "  Required binary not found: ${binary}"
      return 1
    fi
  done

  # Install optional binaries
  for binary in "${OPTIONAL_BINS[@]}"; do
    if [[ -f "${bin_dir}/${binary}" ]]; then
      log::info "  Installing: ${binary}"
      install -m 755 "${bin_dir}/${binary}" "${K8S_BIN_DIR}/"
    else
      log::debug "  Optional binary not found: ${binary}"
    fi
  done

  # Create symlinks for containerd-shim variants
  for shim in "${bin_dir}"/containerd-shim*; do
    [[ -f "${shim}" ]] || continue
    local shim_name
    shim_name=$(basename "${shim}")
    install -m 755 "${shim}" "${K8S_BIN_DIR}/"
    log::info "  Installing: ${shim_name}"
  done

  log::info "Kubernetes binaries installed"
}

# Load container images
install::load_images() {
  local images_dir="${RESOURCES_DIR}/kubernetes/images"

  log::info "Loading container images from: ${images_dir}"

  if [[ ! -d "${images_dir}" ]]; then
    log::warn "Container images directory not found"
    return 0
  fi

  # Determine container runtime
  local runtime=""
  if command -v ctr &>/dev/null; then
    runtime="containerd"
  elif command -v docker &>/dev/null; then
    runtime="docker"
  else
    log::warn "No container runtime available, skipping image loading"
    return 0
  fi

  local loaded=0
  local failed=0

  for image_file in "${images_dir}"/*.tar "${images_dir}"/*.tar.gz; do
    [[ -f "${image_file}" ]] || continue

    local filename
    filename=$(basename "${image_file}")
    log::info "  Loading: ${filename}"

    case "${runtime}" in
      containerd)
        if ctr -n k8s.io images import "${image_file}" >> "${INSTALL_LOG}" 2>&1; then
          ((loaded++)) || true
        else
          ((failed++)) || true
          log::warn "    Failed to load"
        fi
        ;;
      docker)
        if docker load -i "${image_file}" >> "${INSTALL_LOG}" 2>&1; then
          ((loaded++)) || true
        else
          ((failed++)) || true
          log::warn "    Failed to load"
        fi
        ;;
    esac
  done

  log::info "Loaded ${loaded} images (${failed} failed)"
}

# -----------------------------------------------------------------------------
# System Configuration
# -----------------------------------------------------------------------------

# Configure system settings for Kubernetes
install::configure_system() {
  log::info "Configuring system for Kubernetes"

  # Disable swap
  log::info "  Disabling swap"
  swapoff -a
  sed -i '/swap/d' /etc/fstab

  # Load required kernel modules
  log::info "  Loading kernel modules"
  cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

  for module in overlay br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack; do
    modprobe "${module}" 2>/dev/null || log::warn "  Failed to load module: ${module}"
  done

  # Configure sysctl
  log::info "  Configuring sysctl"
  cat > /etc/sysctl.d/k8s.conf << EOF
# Kubernetes sysctl settings
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1

# Performance tuning
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8096
net.core.netdev_max_backlog = 16384

# Memory settings
vm.swappiness = 0
vm.overcommit_memory = 1
vm.panic_on_oom = 0

# File descriptor limits
fs.file-max = 1048576
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
EOF

  sysctl --system >> "${INSTALL_LOG}" 2>&1

  # Disable SELinux if running (optional)
  if command -v getenforce &>/dev/null; then
    if [[ "$(getenforce 2>/dev/null)" != "Disabled" ]]; then
      log::info "  Setting SELinux to permissive"
      setenforce 0 2>/dev/null || true
      sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
    fi
  fi

  # Disable firewalld (optional, for simplicity)
  if systemctl is-active --quiet firewalld; then
    log::info "  Disabling firewalld"
    systemctl stop firewalld
    systemctl disable firewalld
  fi

  log::info "System configured"
}

# Install systemd service files
install::install_services() {
  log::info "Installing systemd service files"

  # kubelet service
  cat > "${SYSTEMD_DIR}/kubelet.service" << 'EOF'
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  # kubelet drop-in for kubeadm
  mkdir -p "${SYSTEMD_DIR}/kubelet.service.d"
  cat > "${SYSTEMD_DIR}/kubelet.service.d/10-kubeadm.conf" << 'EOF'
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/local/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOF

  # containerd service (if not exists)
  if [[ ! -f "${SYSTEMD_DIR}/containerd.service" ]] && \
     [[ ! -f /lib/systemd/system/containerd.service ]] && \
     [[ -f "${K8S_BIN_DIR}/containerd" ]]; then
    cat > "${SYSTEMD_DIR}/containerd.service" << 'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
  fi

  # Reload systemd
  systemctl daemon-reload

  # Enable services
  systemctl enable kubelet 2>/dev/null || true

  if [[ -f "${SYSTEMD_DIR}/containerd.service" ]]; then
    systemctl enable containerd 2>/dev/null || true
  fi

  log::info "Systemd services installed"
}

# -----------------------------------------------------------------------------
# Health Checks
# -----------------------------------------------------------------------------

# Verify installation
install::verify() {
  log::info "Verifying installation"

  local errors=0

  # Check required binaries
  for binary in "${REQUIRED_BINS[@]}"; do
    if command -v "${binary}" &>/dev/null; then
      local version
      version=$("${binary}" version 2>/dev/null | head -1 || echo "unknown")
      log::info "  ✓ ${binary}: ${version}"
    else
      log::error "  ✗ ${binary}: not found"
      ((errors++)) || true
    fi
  done

  # Check optional binaries
  for binary in "${OPTIONAL_BINS[@]}"; do
    if command -v "${binary}" &>/dev/null; then
      log::info "  ✓ ${binary}: available"
    else
      log::debug "  - ${binary}: not installed (optional)"
    fi
  done

  # Check systemd services
  for service in kubelet containerd; do
    if systemctl is-enabled "${service}" &>/dev/null; then
      log::info "  ✓ ${service}.service: enabled"
    else
      log::debug "  - ${service}.service: not enabled"
    fi
  done

  # Check system configuration
  if [[ $(cat /proc/sys/net/ipv4/ip_forward) == "1" ]]; then
    log::info "  ✓ IP forwarding: enabled"
  else
    log::warn "  ✗ IP forwarding: disabled"
    ((errors++))
  fi

  if [[ ! -f /proc/swaps ]] || [[ $(wc -l < /proc/swaps) -le 1 ]]; then
    log::info "  ✓ Swap: disabled"
  else
    log::warn "  ! Swap: still enabled"
  fi

  if [[ ${errors} -eq 0 ]]; then
    log::info "Installation verified successfully"
    return 0
  else
    log::error "Installation verification found ${errors} errors"
    return 1
  fi
}

# Generate installation report
install::generate_report() {
  local report_file="${1:-/var/log/kubexm-install-report.txt}"

  log::info "Generating installation report: ${report_file}"

  {
    echo "KubeXM Installation Report"
    echo "=========================="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    echo "System Information:"
    echo "-------------------"
    echo "OS: ${OS_NAME} (${OS_ID} ${OS_VERSION})"
    echo "Architecture: ${ARCH}"
    echo "Kernel: $(uname -r)"
    echo "CPU: $(nproc) cores"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo ""
    echo "Installed Components:"
    echo "---------------------"

    for binary in "${REQUIRED_BINS[@]}" "${OPTIONAL_BINS[@]}"; do
      if command -v "${binary}" &>/dev/null; then
        echo "✓ ${binary}: $(command -v "${binary}")"
      fi
    done

    echo ""
    echo "Systemd Services:"
    echo "-----------------"
    for service in kubelet containerd docker haproxy keepalived nginx; do
      if systemctl is-enabled "${service}" &>/dev/null; then
        local status
        status=$(systemctl is-active "${service}" 2>/dev/null || echo "inactive")
        echo "✓ ${service}: enabled (${status})"
      fi
    done

    echo ""
    echo "System Configuration:"
    echo "---------------------"
    echo "IP forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
    echo "Swap: $(swapon --show || echo 'disabled')"
    echo "SELinux: $(getenforce 2>/dev/null || echo 'N/A')"

    echo ""
    echo "Container Images:"
    echo "-----------------"
    if command -v ctr &>/dev/null; then
      ctr -n k8s.io images list 2>/dev/null | head -20 || echo "Unable to list images"
    elif command -v docker &>/dev/null; then
      docker images 2>/dev/null | head -20 || echo "Unable to list images"
    fi

    echo ""
    echo "Next Steps:"
    echo "-----------"
    echo "1. Initialize cluster: kubeadm init --config=/path/to/config.yaml"
    echo "2. Configure kubectl: export KUBECONFIG=/etc/kubernetes/admin.conf"
    echo "3. Install CNI: kubectl apply -f /path/to/cni.yaml"
    echo "4. Join worker nodes: kubeadm join ..."

  } > "${report_file}"

  log::info "Report generated: ${report_file}"
}

# -----------------------------------------------------------------------------
# Cleanup Functions
# -----------------------------------------------------------------------------

# Cleanup installation
install::cleanup() {
  log::info "Cleaning up installation"

  # Restore original repositories
  install::restore_repos

  # Unmount ISO if mounted
  install::unmount_iso

  # Clean package cache
  case "${PKG_MANAGER}" in
    yum|dnf) ${PKG_MANAGER} clean all 2>/dev/null || true ;;
    apt) apt-get clean 2>/dev/null || true ;;
  esac

  log::info "Cleanup complete"
}

# -----------------------------------------------------------------------------
# Main Installation Flow
# -----------------------------------------------------------------------------

# Full installation
install::full() {
  local iso_file="${1:-}"
  local config_file="${2:-}"

  log::info "Starting KubeXM offline installation"
  log::info "Installation log: ${INSTALL_LOG}"

  # Initialize log
  mkdir -p "$(dirname "${INSTALL_LOG}")"
  echo "KubeXM Installation Log - $(date)" > "${INSTALL_LOG}"

  # Set trap for cleanup
  trap install::cleanup EXIT

  # Detect system
  install::detect_os
  install::detect_arch

  # Find or mount resources
  if [[ -n "${iso_file}" ]]; then
    install::mount_iso "${iso_file}"
  else
    install::find_resources
  fi

  # Install components
  install::install_packages "${RESOURCES_DIR}/packages/system/${ARCH}" || \
    install::install_packages "${RESOURCES_DIR}/packages/system" || true

  install::install_k8s_binaries

  install::configure_system
  install::install_services

  install::load_images

  # Verify installation
  install::verify

  # Generate report
  install::generate_report

  log::info "Installation complete!"
  log::info ""
  log::info "Next steps:"
  log::info "  1. Review report: /var/log/kubexm-install-report.txt"
  log::info "  2. Initialize cluster: kubeadm init --config=/path/to/config.yaml"
  log::info "  3. Configure kubectl: export KUBECONFIG=/etc/kubernetes/admin.conf"
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
install::main() {
  local action="${1:-}"
  shift || true

  case "${action}" in
    full|install)
      local iso_file="${1:-}"
      local config_file="${2:-}"
      install::full "${iso_file}" "${config_file}"
      ;;
    packages)
      local pkg_dir="${1:?Package directory required}"
      install::detect_os
      install::detect_arch
      install::install_packages "${pkg_dir}"
      ;;
    binaries)
      install::detect_os
      install::detect_arch
      install::find_resources
      install::install_k8s_binaries
      ;;
    images)
      install::detect_os
      install::detect_arch
      install::find_resources
      install::load_images
      ;;
    configure)
      install::configure_system
      install::install_services
      ;;
    verify)
      install::detect_os
      install::detect_arch
      install::verify
      ;;
    report)
      local report_file="${1:-/var/log/kubexm-install-report.txt}"
      install::detect_os
      install::detect_arch
      install::generate_report "${report_file}"
      ;;
    cleanup)
      install::detect_os
      install::cleanup
      ;;
    help|--help|-h)
      cat << 'EOF'
KubeXM Offline Installation

Usage: install.sh <action> [options]

Actions:
  full [iso_file] [config]    Full installation (default)
  install [iso_file]          Alias for full
  packages <pkg_dir>          Install system packages only
  binaries                    Install Kubernetes binaries only
  images                      Load container images only
  configure                   Configure system only
  verify                      Verify installation
  report [output_file]        Generate installation report
  cleanup                     Cleanup and restore repositories
  help                        Show this help

Examples:
  # Full installation from ISO
  install.sh full /path/to/kubexm.iso

  # Full installation (auto-detect resources)
  install.sh full

  # Install packages only
  install.sh packages /mnt/kubexm/packages/system

  # Verify installation
  install.sh verify

  # Generate report
  install.sh report /tmp/report.txt

Resource Search Paths:
  /mnt/kubexm, /media/kubexm, /cdrom, /mnt/cdrom

Requirements:
  - Root privileges
  - Compatible OS (CentOS, Rocky, AlmaLinux, Ubuntu, Debian, etc.)
  - Installation resources (ISO or extracted files)

For more information, see the documentation.
EOF
      ;;
    "")
      # Default action: full install
      install::full
      ;;
    *)
      log::error "Unknown action: ${action}"
      echo "Use 'install.sh help' for usage information"
      return 1
      ;;
  esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Check root
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
  fi

  install::main "$@"
fi
