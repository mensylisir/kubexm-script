#!/usr/bin/env bash
set -euo pipefail

step::cluster.config.dirs.runtime.docker::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local runtime_type cluster_dir nodes
  runtime_type="$(context::get "config_dirs_runtime_type" || true)"
  if [[ "${runtime_type}" != "docker" ]]; then
    return 0
  fi
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  nodes="$(context::get "config_dirs_all_nodes" || true)"
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    if [[ ! -d "${cluster_dir}/${node}/docker" ]]; then
      return 1  # missing dir, need to create
    fi
  done
  return 0  # all dirs exist, skip
}

step::cluster.config.dirs.runtime.docker::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local runtime_type
  runtime_type="$(context::get "config_dirs_runtime_type" || true)"
  if [[ "${runtime_type}" != "docker" ]]; then
    return 0
  fi

  local cluster_dir nodes
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  nodes="$(context::get "config_dirs_all_nodes" || true)"

  local node
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    mkdir -p "${cluster_dir}/${node}/docker"
  done
}

step::cluster.config.dirs.runtime.docker::rollback() { return 0; }

step::cluster.config.dirs.runtime.docker::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
