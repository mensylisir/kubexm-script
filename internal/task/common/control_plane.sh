#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - Control Plane Deploy (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/common/kubeconfig.sh"
source "${KUBEXM_ROOT}/internal/task/common/pki.sh"
source "${KUBEXM_ROOT}/internal/task/common/apiserver.sh"
source "${KUBEXM_ROOT}/internal/task/common/controller_manager.sh"
source "${KUBEXM_ROOT}/internal/task/common/scheduler.sh"

task::kubexm_wait_control_plane() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.wait.apiserver:${KUBEXM_ROOT}/internal/step/kubexm/wait/wait_apiserver.sh" \
    "kubernetes.wait.controller.manager:${KUBEXM_ROOT}/internal/step/kubexm/wait/wait_controller_manager.sh" \
    "kubernetes.wait.scheduler:${KUBEXM_ROOT}/internal/step/kubexm/wait/wait_scheduler.sh"
}

# Full kubexm Control Plane deploy flow
task::kubexm_deploy_control_plane() {
  local ctx="$1"
  shift
  task::kubexm_generate_kubeconfig "${ctx}" "$@"
  task::kubexm_distribute_kubeconfig "${ctx}" "$@"
  task::kubexm_distribute_pki "${ctx}" "$@"
  task::kubexm_install_apiserver "${ctx}" "$@"
  task::kubexm_install_controller_manager "${ctx}" "$@"
  task::kubexm_install_scheduler "${ctx}" "$@"
  task::kubexm_wait_control_plane "${ctx}" "$@"
}

export -f task::kubexm_wait_control_plane
export -f task::kubexm_deploy_control_plane