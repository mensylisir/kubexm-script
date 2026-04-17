#!/usr/bin/env bash
set -euo pipefail

step::cluster.dirs.cni.cilium::check() { return 1; }

step::cluster.dirs.cni.cilium::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local cni_type
  cni_type="$(context::get "cni_type" || true)"
  if [[ "${cni_type}" != "cilium" ]]; then
    return 0
  fi

  local cluster_dir nodes
  cluster_dir="$(context::get "cni_cluster_dir" || true)"
  nodes="$(context::get "cni_all_nodes" || true)"

  local node
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    mkdir -p "${cluster_dir}/${node}/cilium"
  done
}

step::cluster.dirs.cni.cilium::rollback() { return 0; }

step::cluster.dirs.cni.cilium::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}