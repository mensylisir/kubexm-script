#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - Kubelet (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubexm_install_kubelet() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.kubelet.collect.identity:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_collect_identity.sh" \
    "kubernetes.kubelet.collect.settings:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_collect_settings.sh" \
    "kubernetes.kubelet.render.config:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_render_config.sh" \
    "kubernetes.kubelet.collect.service.identity:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_collect_service_identity.sh" \
    "kubernetes.kubelet.collect.service.runtime:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_collect_service_runtime.sh" \
    "kubernetes.kubelet.render.service:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_render_service.sh" \
    "kubernetes.kubelet.copy.config:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_copy_config.sh" \
    "kubernetes.kubelet.copy.service:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_copy_service.sh" \
    "kubernetes.kubelet.systemd:${KUBEXM_ROOT}/internal/step/kubexm/kubelet/kubelet_systemd.sh"
}

export -f task::kubexm_install_kubelet