#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os_load_kernel_modules
# 加载内核模块（overlay, br_netfilter）
# ==============================================================================


step::os.load.kernel.modules::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::os.load.kernel.modules "$@"
}

step::os.load.kernel.modules() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=os.load_kernel_modules] Loading kernel modules..."

  # 加载 overlay 模块
  modprobe overlay || logger::warn "[host=${host}] Failed to load overlay module"

  # 加载 br_netfilter 模块
  modprobe br_netfilter || logger::warn "[host=${host}] Failed to load br_netfilter module"

  # 确保开机自动加载
  cat > /etc/modules-load.d/kubexm.conf << 'EOF'
overlay
br_netfilter
EOF

  logger::info "[host=${host} step=os.load_kernel_modules] Kernel modules loaded"
  return 0
}

step::os.load.kernel.modules::check() {
  # 检查模块是否已加载
  if lsmod | grep -q "^overlay" && lsmod | grep -q "^br_netfilter"; then
    return 0  # 已加载，跳过
  fi
  return 1  # 需要执行
}

step::os.load.kernel.modules::rollback() { return 0; }

step::os.load.kernel.modules::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
