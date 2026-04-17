#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Registry Task - Create
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# -----------------------------------------------------------------------------
# 创建 Registry
# -----------------------------------------------------------------------------
task::create_registry() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "registry.create.check.active:${KUBEXM_ROOT}/internal/step/registry/create_check_active.sh" \
    "registry.create.collect.role:${KUBEXM_ROOT}/internal/step/registry/create_collect_role.sh" \
    "registry.create.collect.arch:${KUBEXM_ROOT}/internal/step/registry/create_collect_arch.sh" \
    "registry.create.collect.settings:${KUBEXM_ROOT}/internal/step/registry/create_collect_settings.sh" \
    "registry.create.render.config:${KUBEXM_ROOT}/internal/step/registry/create_render_config.sh" \
    "registry.create.render.service:${KUBEXM_ROOT}/internal/step/registry/create_render_service.sh" \
    "registry.create.prepare.dirs:${KUBEXM_ROOT}/internal/step/registry/create_prepare_dirs.sh" \
    "registry.create.copy.binary:${KUBEXM_ROOT}/internal/step/registry/create_copy_binary.sh" \
    "registry.create.copy.config:${KUBEXM_ROOT}/internal/step/registry/create_copy_config.sh" \
    "registry.create.copy.service:${KUBEXM_ROOT}/internal/step/registry/create_copy_service.sh" \
    "registry.create.systemd:${KUBEXM_ROOT}/internal/step/registry/create_systemd.sh"
}

export -f task::create_registry