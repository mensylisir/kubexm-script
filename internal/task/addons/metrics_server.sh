#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Addon Task - metrics-server
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::collect_metrics_server_config_dirs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.config.dirs.addon.metrics.server:${KUBEXM_ROOT}/internal/task/common/config/addon_metrics_server.sh"
}

task::render_metrics_server() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.addon.metrics.server:${KUBEXM_ROOT}/internal/task/common/render_addon_metrics_server.sh"
}

task::install_metrics_server() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.install.addon.metrics.server:${KUBEXM_ROOT}/internal/task/common/install_addon_metrics_server.sh"
}

task::delete_metrics_server() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.delete.addon.metrics.server:${KUBEXM_ROOT}/internal/task/common/delete_addon_metrics_server.sh"
}

export -f task::collect_metrics_server_config_dirs
export -f task::render_metrics_server
export -f task::install_metrics_server
export -f task::delete_metrics_server