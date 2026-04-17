#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - Controller Manager (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubexm_install_controller_manager() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.controller.manager.render.service:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/controller_manager_render_service.sh" \
    "kubernetes.controller.manager.copy.service:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/controller_manager_copy_service.sh" \
    "kubernetes.controller.manager.systemd:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/controller_manager_systemd.sh"
}

export -f task::kubexm_install_controller_manager