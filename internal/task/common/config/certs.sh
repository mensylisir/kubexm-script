#!/usr/bin/env bash
set -euo pipefail

step::cluster.config.dirs.certs::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local cluster_dir nodes
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  nodes="$(context::get "config_dirs_all_nodes" || true)"
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    if [[ ! -d "${cluster_dir}/${node}/certs/kubernetes" ]] ||
       [[ ! -d "${cluster_dir}/${node}/certs/etcd" ]]; then
      return 1  # missing dir, need to create
    fi
  done
  return 0  # all dirs exist, skip
}

step::cluster.config.dirs.certs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local cluster_dir nodes
  cluster_dir="$(context::get "config_dirs_cluster_dir" || true)"
  nodes="$(context::get "config_dirs_all_nodes" || true)"

  local node
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    mkdir -p "${cluster_dir}/${node}/certs/kubernetes"
    mkdir -p "${cluster_dir}/${node}/certs/etcd"
  done
}

step::cluster.config.dirs.certs::rollback() { return 0; }

step::cluster.config.dirs.certs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
