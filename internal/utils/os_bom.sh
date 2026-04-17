#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - OS BOM (Bill of Materials)
# ==============================================================================
# 操作系统依赖包管理工具
# 定义不同操作系统和运行时对应的依赖包
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 加载依赖
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"

#######################################
# 获取操作系统类型
# Returns:
#   操作系统标识符
#######################################
utils::os::bom::detect_os() {
  local os_id="unknown"
  local version=""

  if [[ -f /etc/os-release ]]; then
    os_id=$(grep '^ID=' /etc/os-release | cut -d'"' -f2)
    version=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2 | tr -d '.')
  fi

  case "$os_id" in
    ubuntu)
      echo "ubuntu${version}"
      ;;
    centos)
      echo "centos${version}"
      ;;
    fedora)
      echo "fedora"
      ;;
    debian)
      echo "debian"
      ;;
    uos)
      echo "uos20server"
      ;;
    kylin)
      echo "kylinv10sp3"
      ;;
    *)
      echo "$os_id"
      ;;
  esac
}

#######################################
# 获取RPM系OS包名
# Arguments:
#   $1 - 包名（通用名）
# Returns:
#   包名（RPM格式）
#######################################
utils::os::bom::rpm_package_name() {
  local pkg="$1"

  case "$pkg" in
    socat) echo "socat" ;;
    conntrack-tools) echo "conntrack-tools" ;;
    ipset) echo "ipset" ;;
    ebtables) echo "ebtables" ;;
    ethtool) echo "ethtool" ;;
    ipvsadm) echo "ipvsadm" ;;
    open-iscsi) echo "iscsi-initiator-utils" ;;
    nfs) echo "nfs-utils" ;;
    haproxy) echo "haproxy" ;;
    keepalived) echo "keepalived" ;;
    chrony) echo "chrony" ;;
    rsync) echo "rsync" ;;
    nginx) echo "nginx" ;;
    podman) echo "podman" ;;
    cri-o) echo "cri-o" ;;
    fio) echo "fio" ;;
    sysbench) echo "sysbench" ;;
    expect) echo "expect" ;;
    sshpass) echo "sshpass" ;;
    bash-completion) echo "bash-completion" ;;
    iproute2) echo "iproute2" ;;
    iptables) echo "iptables-services" ;;
    *) echo "$pkg" ;;
  esac
}

#######################################
# 获取DEB系OS包名
# Arguments:
#   $1 - 包名（通用名）
# Returns:
#   包名（DEB格式）
#######################################
utils::os::bom::deb_package_name() {
  local pkg="$1"

  case "$pkg" in
    socat) echo "socat" ;;
    conntrack-tools) echo "conntrack" ;;
    ipset) echo "ipset" ;;
    ebtables) echo "ebtables" ;;
    ethtool) echo "ethtool" ;;
    ipvsadm) echo "ipvsadm" ;;
    open-iscsi) echo "open-iscsi" ;;
    nfs) echo "nfs-common" ;;
    haproxy) echo "haproxy" ;;
    keepalived) echo "keepalived" ;;
    chrony) echo "chrony" ;;
    rsync) echo "rsync" ;;
    nginx) echo "nginx" ;;
    podman) echo "podman" ;;
    cri-o) echo "cri-o" ;;
    fio) echo "fio" ;;
    sysbench) echo "sysbench" ;;
    expect) echo "expect" ;;
    sshpass) echo "sshpass" ;;
    bash-completion) echo "bash-completion" ;;
    iproute2) echo "iproute2" ;;
    iptables) echo "iptables" ;;
    software-properties-common) echo "software-properties-common" ;;
    apt-transport-https) echo "apt-transport-https" ;;
    ca-certificates) echo "ca-certificates" ;;
    gnupg) echo "gnupg" ;;
    lsb-release) echo "lsb-release" ;;
    *) echo "$pkg" ;;
  esac
}

#######################################
# 获取基础系统包（所有OS都需要）
# Arguments:
#   无
# Returns:
#   基础包列表
#######################################
utils::os::bom::get_base_packages() {
  local packages=(
    "curl"
    "wget"
    "jq"
    "htop"
    "vim"
    "git"
    "tar"
    "gzip"
    "unzip"
    "expect"
    "sshpass"
    "bash-completion"
  )

  echo "${packages[@]}"
}

#######################################
# 获取Kubernetes组件依赖包
# Arguments:
#   无
# Returns:
#   K8s包列表
#######################################
utils::os::bom::get_kubernetes_packages() {
  local packages=(
    "conntrack-tools"
    "ebtables"
    "ethtool"
  )

  echo "${packages[@]}"
}

#######################################
# 获取容器运行时依赖包
# Arguments:
#   $1 - 运行时类型 (docker|containerd|crio|podman)
# Returns:
#   运行时包列表
#######################################
utils::os::bom::get_runtime_packages() {
  local runtime_type="$1"
  local packages=()

  case "$runtime_type" in
    docker)
      packages+=("docker.io" "docker-compose")
      ;;
    containerd)
      packages+=("containerd" "runc")
      ;;
    crio)
      packages+=("crio" "runc" "fio" "sysbench")
      ;;
    podman)
      packages+=("podman" "buildah")
      ;;
  esac

  echo "${packages[@]}"
}

#######################################
# 获取网络插件依赖包
# Arguments:
#   $1 - CNI类型 (calico|flannel|cilium|kubeovn|hybridnet|multus)
# Returns:
#   网络包列表
#######################################
utils::os::bom::get_cni_packages() {
  local cni_type="$1"
  local packages=()

  case "$cni_type" in
    calico|flannel|cilium)
      packages+=("iproute2" "iptables")
      ;;
    kubeovn|hybridnet)
      packages+=("iproute2" "iptables")
      ;;
    multus)
      packages+=("iproute2" "iptables")
      ;;
  esac

  echo "${packages[@]}"
}

#######################################
# 获取负载均衡器依赖包
# Arguments:
#   $1 - LB类型 (haproxy|nginx|keepalived|kube-vip)
# Returns:
#   LB包列表
#######################################
utils::os::bom::get_loadbalancer_packages() {
  local lb_type="$1"
  local packages=()

  case "$lb_type" in
    haproxy)
      packages+=("haproxy" "keepalived")
      ;;
    nginx)
      packages+=("nginx" "keepalived")
      ;;
    keepalived)
      packages+=("keepalived")
      ;;
    kube-vip)
      packages+=("keepalived")
      ;;
  esac

  echo "${packages[@]}"
}

#######################################
# 获取存储插件依赖包
# Arguments:
#   $1 - 存储类型 (nfs|ceph|glusterfs|iscsi)
# Returns:
#   存储包列表
#######################################
utils::os::bom::get_storage_packages() {
  local storage_type="$1"
  local packages=()

  case "$storage_type" in
    nfs)
      packages+=("nfs-common" "nfs-kernel-server")
      ;;
    ceph)
      packages+=("ceph-common")
      ;;
    glusterfs)
      packages+=("glusterfs-client" "glusterfs-common")
      ;;
    iscsi)
      packages+=("open-iscsi" "iscsi-initiator-utils")
      ;;
  esac

  echo "${packages[@]}"
}

#######################################
# 获取Helm依赖包
# Arguments:
#   无
# Returns:
#   Helm包列表
#######################################
utils::os::bom::get_helm_packages() {
  local packages=(
    "gpg"
    "gnupg-agent"
    "software-properties-common"
  )

  echo "${packages[@]}"
}

#######################################
# 获取时序同步依赖包
# Arguments:
#   无
# Returns:
#   时序包列表
#######################################
utils::os::bom::get_timesync_packages() {
  local packages=(
    "chrony"
    "ntp"
  )

  echo "${packages[@]}"
}

#######################################
# 获取所有依赖包（根据OS和配置）
# Arguments:
#   $1 - 操作系统类型
#   $2 - 容器运行时类型
#   $3 - CNI类型
#   $4 - LB类型
# Returns:
#   所有包列表
#######################################
utils::os::bom::get_all_packages() {
  local os_type="$1"
  local runtime_type="${2:-$(defaults::get_runtime_type)}"
  local cni_type="${3:-$(defaults::get_cni_plugin)}"
  local lb_type="${4:-$(defaults::get_loadbalancer_type)}"

  local all_packages=()

  # 基础包
  for pkg in $(utils::os::bom::get_base_packages); do
    all_packages+=("$pkg")
  done

  # K8s包
  for pkg in $(utils::os::bom::get_kubernetes_packages); do
    all_packages+=("$pkg")
  done

  # 运行时包
  for pkg in $(utils::os::bom::get_runtime_packages "$runtime_type"); do
    all_packages+=("$pkg")
  done

  # CNI包
  for pkg in $(utils::os::bom::get_cni_packages "$cni_type"); do
    all_packages+=("$pkg")
  done

  # LB包
  for pkg in $(utils::os::bom::get_loadbalancer_packages "$lb_type"); do
    all_packages+=("$pkg")
  done

  # 存储包
  for pkg in $(utils::os::bom::get_storage_packages "nfs"); do
    all_packages+=("$pkg")
  done

  # 时序包
  for pkg in $(utils::os::bom::get_timesync_packages); do
    all_packages+=("$pkg")
  done

  # Helm包
  for pkg in $(utils::os::bom::get_helm_packages); do
    all_packages+=("$pkg")
  done

  # 去重并输出
  printf '%s\n' "${all_packages[@]}" | sort -u
}

#######################################
# 安装OS依赖包
# Arguments:
#   $1 - 包列表
# Returns:
#   0 成功, 1 失败
#######################################
utils::os::bom::install_packages() {
  local packages=("$@")

  if [[ ${#packages[@]} -eq 0 ]]; then
    log::info "No packages to install"
    return 0
  fi

  log::info "Installing ${#packages[@]} packages..."

  # 检测包管理器
  if utils::command_exists apt-get; then
    # DEB系 (Ubuntu, Debian, UOS, Kylin)
    log::info "Using apt-get package manager..."

    # 更新包列表
    apt-get update >/dev/null 2>&1

    # 转换包名
    local deb_packages=()
    for pkg in "${packages[@]}"; do
      deb_packages+=("$(utils::os::bom::deb_package_name "$pkg")")
    done

    # 安装包
    apt-get install -y "${deb_packages[@]}" >/dev/null 2>&1 || {
      log::error "Failed to install packages"
      return 1
    }

  elif utils::command_exists yum; then
    # RPM系 (CentOS, RHEL, Fedora)
    log::info "Using yum package manager..."

    # 转换包名
    local rpm_packages=()
    for pkg in "${packages[@]}"; do
      rpm_packages+=("$(utils::os::bom::rpm_package_name "$pkg")")
    done

    # 安装包
    yum install -y "${rpm_packages[@]}" >/dev/null 2>&1 || {
      log::error "Failed to install packages"
      return 1
    }

  elif utils::command_exists dnf; then
    # DNF (Fedora, RHEL 8+)
    log::info "Using dnf package manager..."

    # 转换包名
    local rpm_packages=()
    for pkg in "${packages[@]}"; do
      rpm_packages+=("$(utils::os::bom::rpm_package_name "$pkg")")
    done

    # 安装包
    dnf install -y "${rpm_packages[@]}" >/dev/null 2>&1 || {
      log::error "Failed to install packages"
      return 1
    }

  else
    log::error "No supported package manager found (apt-get, yum, dnf)"
    return 1
  fi

  log::success "All packages installed successfully"
  return 0
}

#######################################
# 生成OS BOM文件
# Arguments:
#   $1 - 输出文件路径
#   $2 - 操作系统类型
#   $3 - 容器运行时类型
#   $4 - CNI类型
#   $5 - LB类型
# Returns:
#   0 成功, 1 失败
#######################################
utils::os::bom::generate_bom() {
  local output_file="$1"
  local os_type="${2:-$(utils::os::bom::detect_os)}"
  local runtime_type="${3:-$(defaults::get_runtime_type)}"
  local cni_type="${4:-$(defaults::get_cni_plugin)}"
  local lb_type="${5:-$(defaults::get_loadbalancer_type)}"

  log::info "Generating OS BOM for $os_type..."

  {
    echo "# OS Package Bill of Materials"
    echo "# Generated: $(date)"
    echo "# OS Type: $os_type"
    echo "# Runtime: $runtime_type"
    echo "# CNI: $cni_type"
    echo "# Load Balancer: $lb_type"
    echo ""

    echo "# Base System Packages"
    for pkg in $(utils::os::bom::get_base_packages); do
      echo "  - $pkg"
    done
    echo ""

    echo "# Kubernetes Dependencies"
    for pkg in $(utils::os::bom::get_kubernetes_packages); do
      echo "  - $pkg"
    done
    echo ""

    echo "# Container Runtime ($runtime_type)"
    for pkg in $(utils::os::bom::get_runtime_packages "$runtime_type"); do
      echo "  - $pkg"
    done
    echo ""

    echo "# CNI Plugin ($cni_type)"
    for pkg in $(utils::os::bom::get_cni_packages "$cni_type"); do
      echo "  - $pkg"
    done
    echo ""

    echo "# Load Balancer ($lb_type)"
    for pkg in $(utils::os::bom::get_loadbalancer_packages "$lb_type"); do
      echo "  - $pkg"
    done
    echo ""

    echo "# Storage"
    for pkg in $(utils::os::bom::get_storage_packages "nfs"); do
      echo "  - $pkg"
    done
    echo ""

    echo "# Time Synchronization"
    for pkg in $(utils::os::bom::get_timesync_packages); do
      echo "  - $pkg"
    done
    echo ""

    echo "# Helm"
    for pkg in $(utils::os::bom::get_helm_packages); do
      echo "  - $pkg"
    done
    echo ""

    echo "# All Packages (for automation)"
    echo "PACKAGES=\""
    for pkg in $(utils::os::bom::get_all_packages "$os_type" "$runtime_type" "$cni_type" "$lb_type"); do
      echo "  $pkg"
    done
    echo "\""

  } > "$output_file"

  log::success "OS BOM generated: $output_file"
  return 0
}

# 导出函数
export -f utils::os::bom::detect_os
export -f utils::os::bom::rpm_package_name
export -f utils::os::bom::deb_package_name
export -f utils::os::bom::get_base_packages
export -f utils::os::bom::get_kubernetes_packages
export -f utils::os::bom::get_runtime_packages
export -f utils::os::bom::get_cni_packages
export -f utils::os::bom::get_loadbalancer_packages
export -f utils::os::bom::get_storage_packages
export -f utils::os::bom::get_helm_packages
export -f utils::os::bom::get_timesync_packages
export -f utils::os::bom::get_all_packages
export -f utils::os::bom::install_packages
export -f utils::os::bom::generate_bom
