#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - Kube Proxy (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubexm_install_kube_proxy() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.kube.proxy.collect.identity:${KUBEXM_ROOT}/internal/step/kubexm/kube-proxy/kube_proxy_collect_identity.sh" \
    "kubernetes.kube.proxy.collect.settings:${KUBEXM_ROOT}/internal/step/kubexm/kube-proxy/kube_proxy_collect_settings.sh" \
    "kubernetes.kube.proxy.render.config:${KUBEXM_ROOT}/internal/step/kubexm/kube-proxy/kube_proxy_render_config.sh" \
    "kubernetes.kube.proxy.render.service:${KUBEXM_ROOT}/internal/step/kubexm/kube-proxy/kube_proxy_render_service.sh" \
    "kubernetes.kube.proxy.copy.config:${KUBEXM_ROOT}/internal/step/kubexm/kube-proxy/kube_proxy_copy_config.sh" \
    "kubernetes.kube.proxy.copy.service:${KUBEXM_ROOT}/internal/step/kubexm/kube-proxy/kube_proxy_copy_service.sh" \
    "kubernetes.kube.proxy.systemd:${KUBEXM_ROOT}/internal/step/kubexm/kube-proxy/kube_proxy_systemd.sh"
}

export -f task::kubexm_install_kube_proxy