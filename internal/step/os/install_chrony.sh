#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os_install_chrony
# 安装 chrony 时间同步工具
# ==============================================================================


step::os.install.chrony::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::os.install.chrony "$@"
}

step::os.install.chrony() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=os.install_chrony] Installing chrony..."

  # 检测包管理器
  if command -v apt-get &>/dev/null; then
    apt-get update -qq
    apt-get install -y chrony >/dev/null 2>&1
  elif command -v yum &>/dev/null; then
    yum install -y chrony >/dev/null 2>&1
  elif command -v dnf &>/dev/null; then
    dnf install -y chrony >/dev/null 2>&1
  elif command -v zypper &>/dev/null; then
    zypper install -y chrony >/dev/null 2>&1
  fi

  logger::info "[host=${host} step=os.install_chrony] Chrony installed"
  return 0
}

step::os.install.chrony::check() {
  # 检查 chrony 是否已安装
  if command -v chronyd &>/dev/null || command -v chrony &>/dev/null; then
    return 0  # 已安装，跳过
  fi
  return 1  # 需要执行
}

step::os.install.chrony::rollback() { return 0; }

step::os.install.chrony::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
