#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Task: Scale Update Hosts and LB
# ==============================================================================
# scale-out 或 scale-in 后更新 /etc/hosts 和 LoadBalancer 配置
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::scale_update_hosts() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "os.update.hosts:${KUBEXM_ROOT}/internal/step/os/update_hosts.sh"
  
  # Also update load balancer configuration after hosts update
  logger::info "[Task:scale] Updating load balancer configuration..."
  task::update_lb_config "${ctx}" "$@" || {
    logger::warn "[Task:scale] LB config update failed, continuing..."
    logger::warn "[Task:scale] You may need to manually update LB backends"
  }
}

export -f task::scale_update_hosts
