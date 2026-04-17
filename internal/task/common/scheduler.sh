#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - Scheduler (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubexm_install_scheduler() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.scheduler.render.service:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/scheduler_render_service.sh" \
    "kubernetes.scheduler.copy.service:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/scheduler_copy_service.sh" \
    "kubernetes.scheduler.systemd:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/scheduler_systemd.sh"
}

export -f task::kubexm_install_scheduler