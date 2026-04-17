#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - API Server (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubexm_install_apiserver() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubernetes.apiserver.collect.identity:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/apiserver_collect_identity.sh" \
    "kubernetes.apiserver.collect.etcd.servers:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/apiserver_collect_etcd_servers.sh" \
    "kubernetes.apiserver.collect.service.settings:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/apiserver_collect_service_settings.sh" \
    "kubernetes.apiserver.collect.audit.settings:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/apiserver_collect_audit_settings.sh" \
    "kubernetes.apiserver.render.service:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/apiserver_render_service.sh" \
    "kubernetes.apiserver.prepare.dirs:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/apiserver_prepare_dirs.sh" \
    "kubernetes.apiserver.copy.service:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/apiserver_copy_service.sh" \
    "kubernetes.apiserver.systemd:${KUBEXM_ROOT}/internal/step/kubexm/control-plane/apiserver_systemd.sh"
}

export -f task::kubexm_install_apiserver