#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LB Task - kubexm-kh (keepalived + haproxy) external
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_lb_external_kubexm_kh() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.external.kubexm.kh.collect.haproxy.identity:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/collect_haproxy_identity.sh" \
    "lb.external.kubexm.kh.collect.haproxy.backends:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/collect_haproxy_backends.sh" \
    "lb.external.kubexm.kh.render.haproxy.config:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/render_haproxy_config.sh" \
    "lb.external.kubexm.kh.collect.keepalived.identity:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/collect_keepalived_identity.sh" \
    "lb.external.kubexm.kh.collect.keepalived.settings:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/collect_keepalived_settings.sh" \
    "lb.external.kubexm.kh.render.keepalived.config:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/render_keepalived_config.sh" \
    "lb.external.kubexm.kh.render.check.script:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/render_check_script.sh" \
    "lb.external.kubexm.kh.prepare.dirs:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/prepare_dirs.sh" \
    "lb.external.kubexm.kh.copy.haproxy.config:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/copy_haproxy_config.sh" \
    "lb.external.kubexm.kh.copy.keepalived.config:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/copy_keepalived_config.sh" \
    "lb.external.kubexm.kh.copy.check.script:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/copy_check_script.sh" \
    "lb.external.kubexm.kh.chmod.check.script:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/chmod_check_script.sh" \
    "lb.external.kubexm.kh.enable:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/systemd.sh"
}

task::delete_lb_external_kubexm_kh() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "lb.external.kubexm.kh.delete:${KUBEXM_ROOT}/internal/step/loadbalancer/external/kubexm-kh/delete.sh"
}

export -f task::install_lb_external_kubexm_kh
export -f task::delete_lb_external_kubexm_kh