#!/usr/bin/env bash
set -euo pipefail

step::cluster.config.dirs.runtime.crio::check() { return 1; }

step::cluster.config.dirs.runtime.crio::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local runtime_type
  runtime_type="$(context::get "config_dirs_runtime_type" || true)"
  if [[ "${runtime_type}" != "crio" ]]; then
    return 0
  fi

  local cluster_dir nodes
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  nodes="$(context::get "config_dirs_all_nodes" || true)"

  local node
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    mkdir -p "${cluster_dir}/${node}/crio"
  done
}

step::cluster.config.dirs.runtime.crio::rollback() { return 0; }

step::cluster.config.dirs.runtime.crio::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
