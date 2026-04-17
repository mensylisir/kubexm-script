#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Common Utilities
# ==============================================================================
# 通用工具函数库
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 加载依赖
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"

#######################################
# 检查命令是否存在
# Arguments:
#   $1 - 命令名
# Returns:
#   0 存在, 1 不存在
#######################################
utils::command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#######################################
# 检查包是否已安装
# Arguments:
#   $1 - 包名
# Returns:
#   0 已安装, 1 未安装
#######################################
utils::package_installed() {
  local package="$1"

  if utils::command_exists dpkg; then
    dpkg -l "$package" 2>/dev/null | grep -q "^ii"
  elif utils::command_exists rpm; then
    rpm -q "$package" >/dev/null 2>&1
  else
    return 1
  fi
}

#######################################
# 安装包（自动检测包管理器）
# Arguments:
#   $1 - 包名
# Returns:
#   0 成功, 1 失败
#######################################
utils::install_package() {
  local package="$1"

  log::info "Installing package: $package"

  if utils::command_exists apt-get; then
    apt-get update >/dev/null 2>&1 && apt-get install -y "$package"
  elif utils::command_exists yum; then
    yum install -y "$package"
  elif utils::command_exists dnf; then
    dnf install -y "$package"
  else
    log::error "No package manager found"
    return 1
  fi
}

#######################################
# 卸载包
# Arguments:
#   $1 - 包名
# Returns:
#   0 成功, 1 失败
#######################################
utils::remove_package() {
  local package="$1"

  log::info "Removing package: $package"

  if utils::command_exists apt-get; then
    apt-get remove -y "$package"
  elif utils::command_exists yum; then
    yum remove -y "$package"
  elif utils::command_exists dnf; then
    dnf remove -y "$package"
  else
    log::error "No package manager found"
    return 1
  fi
}

#######################################
# 获取操作系统类型
# Returns:
#   操作系统标识符
#######################################
utils::get_os_type() {
  if [[ -f /etc/os-release ]]; then
    local os_id
    os_id=$(grep '^ID=' /etc/os-release | cut -d'"' -f2)

    case "$os_id" in
      ubuntu)
        local version
        version=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2 | tr -d '.')
        echo "ubuntu${version}"
        ;;
      centos)
        local version
        version=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2 | cut -d'.' -f1)
        echo "centos${version}"
        ;;
      fedora)
        echo "fedora"
        ;;
      debian)
        echo "debian"
        ;;
      uos)
        local version
        version=$(grep '^VERSION=' /etc/os-release | cut -d' ' -f2 | tr -d '()' | tr -d '.')
        echo "uos${version}"
        ;;
      kylin)
        local version
        version=$(grep '^VERSION=' /etc/os-release | cut -d' ' -f2 | tr -d '()' | tr -d '.')
        echo "kylin${version}"
        ;;
      *)
        echo "$os_id"
        ;;
    esac
  else
    echo "unknown"
  fi
}

#######################################
# 检测系统架构
# Returns:
#   架构标识符 (amd64, arm64等)
#######################################
utils::get_arch() {
  uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'
}

#######################################
# 检查是否为root用户
# Returns:
#   0 是root, 1 不是
#######################################
utils::is_root() {
  [[ $EUID -eq 0 ]]
}

#######################################
# 创建目录（如果不存在）
# Arguments:
#   $1 - 目录路径
# Returns:
#   0 成功, 1 失败
#######################################
utils::ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || return 1
  fi
  return 0
}

#######################################
# 清理目录
# Arguments:
#   $1 - 目录路径
# Returns:
#   0 成功, 1 失败
#######################################
utils::clean_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    rm -rf "$dir" || return 1
  fi
  mkdir -p "$dir" || return 1
  return 0
}

#######################################
# 等待文件或目录存在
# Arguments:
#   $1 - 路径
#   $2 - 超时秒数（默认60）
# Returns:
#   0 存在, 1 超时
#######################################
utils::wait_for_file() {
  local path="$1"
  local timeout="${2:-$(defaults::get_command_timeout)}"
  local count=0

  while [[ ! -e "$path" && $count -lt $timeout ]]; do
    sleep 1
    ((count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  done

  [[ -e "$path" ]]
}

#######################################
# 等待服务就绪
# Arguments:
#   $1 - 服务名
#   $2 - 超时秒数（默认60）
# Returns:
#   0 就绪, 1 超时
#######################################
utils::wait_for_service() {
  local service="$1"
  local timeout="${2:-$(defaults::get_command_timeout)}"
  local count=0

  while [[ $count -lt $timeout ]]; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
      return 0
    fi
    sleep 1
    ((count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  done

  return 1
}

#######################################
# 等待端口可访问
# Arguments:
#   $1 - 主机
#   $2 - 端口
#   $3 - 超时秒数（默认60）
# Returns:
#   0 可访问, 1 超时
#######################################
utils::wait_for_port() {
  local host="$1"
  local port="$2"
  local timeout="${3:-$(defaults::get_command_timeout)}"
  local count=0

  while [[ $count -lt $timeout ]]; do
    if timeout 1 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
      return 0
    fi
    sleep 1
    ((count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  done

  return 1
}

#######################################
# 下载文件
# Arguments:
#   $1 - URL
#   $2 - 输出文件
#   $3 - 备用URL（可选）
# Returns:
#   0 成功, 1 失败
#######################################
utils::download_file() {
  local url="$1"
  local output="$2"
  local fallback_url="${3:-}"

  log::info "Downloading: $url"

  if utils::command_exists wget; then
    wget -q -O "$output" "$url" || {
      if [[ -n "$fallback_url" ]]; then
        log::warn "Primary URL failed, trying fallback: $fallback_url"
        wget -q -O "$output" "$fallback_url" || return 1
      else
        return 1
      fi
    }
  elif utils::command_exists curl; then
    curl -fsSL -o "$output" "$url" || {
      if [[ -n "$fallback_url" ]]; then
        log::warn "Primary URL failed, trying fallback: $fallback_url"
        curl -fsSL -o "$output" "$fallback_url" || return 1
      else
        return 1
      fi
    }
  else
    log::error "Neither wget nor curl is available"
    return 1
  fi

  log::success "Downloaded: $output"
  return 0
}

#######################################
# 校验文件SHA256
# Arguments:
#   $1 - 文件路径
#   $2 - 期望的SHA256值
# Returns:
#   0 匹配, 1 不匹配
#######################################
utils::verify_sha256() {
  local file="$1"
  local expected_sha256="$2"

  if [[ ! -f "$file" ]]; then
    log::error "File not found: $file"
    return 1
  fi

  local actual_sha256
  actual_sha256=$(sha256sum "$file" | cut -d' ' -f1)

  if [[ "$actual_sha256" == "$expected_sha256" ]]; then
    return 0
  else
    log::error "SHA256 mismatch: expected $expected_sha256, got $actual_sha256"
    return 1
  fi
}

# 导出函数
export -f utils::command_exists
export -f utils::package_installed
export -f utils::install_package
export -f utils::remove_package
export -f utils::get_os_type
export -f utils::get_arch
export -f utils::is_root
export -f utils::ensure_dir
export -f utils::clean_dir
export -f utils::wait_for_file
export -f utils::wait_for_service
export -f utils::wait_for_port
export -f utils::download_file
export -f utils::verify_sha256
