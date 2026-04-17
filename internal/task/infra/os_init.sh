#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Task: OSInit - 系统初始化
# ==============================================================================
# 包含：
# - disable_swap
# - stop_firewall
# - modify_sysctl
# - load_kernel_modules
# - install_base_packages
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# 执行系统初始化
# -----------------------------------------------------------------------------
task::os_init() {
  local ctx="$1"
  shift

  task::run_steps "${ctx}" "$@" -- \
    "os.disable.swap:${KUBEXM_ROOT}/internal/step/os/disable_swap.sh" \
    "os.stop.firewall:${KUBEXM_ROOT}/internal/step/os/stop_firewall.sh" \
    "os.modify.sysctl:${KUBEXM_ROOT}/internal/step/os/modify_sysctl.sh" \
    "os.load.kernel.modules:${KUBEXM_ROOT}/internal/step/os/load_kernel_modules.sh" \
    "os.install.base.packages:${KUBEXM_ROOT}/internal/step/os/install_base_packages.sh" \
    "os.configure.hosts:${KUBEXM_ROOT}/internal/step/os/configure_hosts.sh"
}

export -f task::os_init
