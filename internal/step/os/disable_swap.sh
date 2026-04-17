#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os_disable_swap
# 禁用 Swap
# ==============================================================================


step::os.disable.swap::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::os.disable.swap "$@"
}

step::os.disable.swap() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=os.disable_swap] Disabling swap..."

  # 检查是否已禁用
  if swapon -s | grep -q "Filename"; then
    # 禁用所有 swap
    swapoff -a || true
    # 注释掉 fstab 中的 swap 行
    sed -i '/^[^#]*swap[[:space:]]/s/^/#/' /etc/fstab || true
  fi

  logger::info "[host=${host} step=os.disable_swap] Swap disabled"
  return 0
}

step::os.disable.swap::check() {
  # 检查 swap 是否已禁用
  if swapon -s | grep -q "Filename"; then
    return 1  # 需要执行
  fi
  return 0  # 已禁用，跳过
}

step::os.disable.swap::rollback() { return 0; }

step::os.disable.swap::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
