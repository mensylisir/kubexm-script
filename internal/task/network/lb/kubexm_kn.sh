#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - kubexm-kn (keepalived + nginx) external
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_lb_external_kubexm_kn() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.external.kubexm.kn.collect.nginx.identity:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/collect_nginx_identity.sh" \
    "lb.external.kubexm.kn.collect.nginx.upstream:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/collect_nginx_upstream.sh" \
    "lb.external.kubexm.kn.render.nginx.config:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/render_nginx_config.sh" \
    "lb.external.kubexm.kn.collect.keepalived.identity:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/collect_keepalived_identity.sh" \
    "lb.external.kubexm.kn.collect.keepalived.settings:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/collect_keepalived_settings.sh" \
    "lb.external.kubexm.kn.render.keepalived.config:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/render_keepalived_config.sh" \
    "lb.external.kubexm.kn.render.check.script:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/render_check_script.sh" \
    "lb.external.kubexm.kn.prepare.dirs:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/prepare_dirs.sh" \
    "lb.external.kubexm.kn.copy.nginx.config:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/copy_nginx_config.sh" \
    "lb.external.kubexm.kn.copy.keepalived.config:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/copy_keepalived_config.sh" \
    "lb.external.kubexm.kn.copy.check.script:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/copy_check_script.sh" \
    "lb.external.kubexm.kn.chmod.check.script:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/chmod_check_script.sh" \
    "lb.external.kubexm.kn.enable:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/systemd.sh"
}

task::delete_lb_external_kubexm_kn() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.external.kubexm.kn.delete:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kn/delete.sh"
}

export -f task::install_lb_external_kubexm_kn
export -f task::delete_lb_external_kubexm_kn