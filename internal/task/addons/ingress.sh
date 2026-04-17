#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Addon Task - ingress
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_ingress_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.addon.ingress:${KUBEXM_ROOT}/internal/task/common/config/addon_ingress.sh"
}

task::render_ingress() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.addon.ingress:${KUBEXM_ROOT}/internal/task/common/render/addon_ingress.sh"
}

task::install_ingress() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.addon.ingress:${KUBEXM_ROOT}/internal/task/common/addon/install_addon_ingress.sh"
}

task::delete_ingress() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.delete.addon.ingress:${KUBEXM_ROOT}/internal/task/common/addon/install_addon_ingress.sh"
}

export -f task::collect_ingress_config_dirs
export -f task::render_ingress
export -f task::install_ingress
export -f task::delete_ingress