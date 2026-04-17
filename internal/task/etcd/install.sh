#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Etcd Task - Install
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::etcd_render_config() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.render.config:${KUBEXM_ROOT}/internal/step/kubexm/etcd/render_config.sh"
}

task::etcd_render_service() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.render.service:${KUBEXM_ROOT}/internal/step/kubexm/etcd/render_service.sh"
}

task::etcd_prepare_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.prepare.dirs:${KUBEXM_ROOT}/internal/step/kubexm/etcd/prepare_dirs.sh"
}

task::etcd_copy_binaries() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.copy.binaries.collect.identity:${KUBEXM_ROOT}/internal/step/kubexm/etcd/copy_binaries_collect_identity.sh" \
    "etcd.copy.binaries.collect.paths:${KUBEXM_ROOT}/internal/step/kubexm/etcd/copy_binaries_collect_paths.sh" \
    "etcd.copy.binaries.copy:${KUBEXM_ROOT}/internal/step/kubexm/etcd/copy_binaries_copy.sh"
}

task::etcd_copy_certs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.copy.certs.collect:${KUBEXM_ROOT}/internal/step/kubexm/etcd/copy_certs_collect.sh" \
    "etcd.copy.certs.files:${KUBEXM_ROOT}/internal/step/kubexm/etcd/copy_certs_files.sh" \
    "etcd.copy.certs.permissions:${KUBEXM_ROOT}/internal/step/kubexm/etcd/copy_certs_permissions.sh"
}

task::etcd_copy_config() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.copy.config:${KUBEXM_ROOT}/internal/step/kubexm/etcd/copy_config.sh"
}

task::etcd_copy_service() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.copy.service:${KUBEXM_ROOT}/internal/step/kubexm/etcd/copy_service.sh"
}

task::etcd_enable_systemd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.systemd:${KUBEXM_ROOT}/internal/step/kubexm/etcd/systemd.sh"
}

task::etcd_wait_ready() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "etcd.wait.ready:${KUBEXM_ROOT}/internal/step/kubexm/etcd/wait_ready.sh"
}

# Full etcd install flow
task::install_etcd() {
  local ctx="$1"
  shift
  task::etcd_render_config "${ctx}" "$@"
  task::etcd_render_service "${ctx}" "$@"
  task::etcd_prepare_dirs "${ctx}" "$@"
  task::etcd_copy_binaries "${ctx}" "$@"
  task::etcd_copy_certs "${ctx}" "$@"
  task::etcd_copy_config "${ctx}" "$@"
  task::etcd_copy_service "${ctx}" "$@"
  task::etcd_enable_systemd "${ctx}" "$@"
  task::etcd_wait_ready "${ctx}" "$@"
}

export -f task::etcd_render_config
export -f task::etcd_render_service
export -f task::etcd_prepare_dirs
export -f task::etcd_copy_binaries
export -f task::etcd_copy_certs
export -f task::etcd_copy_config
export -f task::etcd_copy_service
export -f task::etcd_enable_systemd
export -f task::etcd_wait_ready
export -f task::install_etcd
