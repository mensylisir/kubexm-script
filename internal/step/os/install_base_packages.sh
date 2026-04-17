#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os_install_base_packages
# 安装基础包（socat, conntrack, ipset, curl）
# ==============================================================================


step::os.install.base.packages::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::os.install.base.packages "$@"
}

step::os.install.base.packages() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=os.install_base_packages] Installing base packages..."

  # 检测包管理器
  if command -v apt-get &>/dev/null; then
    apt-get update -qq
    apt-get install -y socat conntrack ipset curl >/dev/null 2>&1
  elif command -v yum &>/dev/null; then
    yum install -y socat conntrack ipset curl >/dev/null 2>&1
  elif command -v dnf &>/dev/null; then
    dnf install -y socat conntrack ipset curl >/dev/null 2>&1
  elif command -v zypper &>/dev/null; then
    zypper install -y socat conntrack ipset curl >/dev/null 2>&1
  fi

  logger::info "[host=${host} step=os.install_base_packages] Base packages installed"
  return 0
}

step::os.install.base.packages::check() {
  # 检查包是否已安装
  local missing=""
  for pkg in socat conntrack curl; do
    if ! command -v "${pkg}" &>/dev/null; then
      missing="${missing} ${pkg}"
    fi
  done

  if [[ -n "${missing}" ]]; then
    return 1  # 需要执行
  fi
  return 0  # 已安装，跳过
}

step::os.install.base.packages::rollback() { return 0; }

step::os.install.base.packages::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
