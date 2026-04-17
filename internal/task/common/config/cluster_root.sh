#!/usr/bin/env bash
set -euo pipefail

step::cluster.config.dirs.cluster.root::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::dir_exists "$(context::get "config_dirs_cluster_dir" || true)"
}

step::cluster.config.dirs.cluster.root::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local cluster_dir
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  if [[ -z "${cluster_dir}" ]]; then
    log::error "Missing cluster_dir for config dirs"
    return 1
  fi

  mkdir -p "${cluster_dir}"
  log::success "Cluster configuration directories created: ${cluster_dir}"
}

step::cluster.config.dirs.cluster.root::rollback() { return 0; }

step::cluster.config.dirs.cluster.root::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
