#!/usr/bin/env bash
set -euo pipefail

step::runtime.cri.dockerd.collect.paths::check() { return 1; }

step::runtime.cri.dockerd.collect.paths::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local node_name cluster_dir
  node_name=$(context::get "runtime_cri_dockerd_node_name")
  cluster_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}"

  context::set "runtime_cri_dockerd_cluster_dir" "${cluster_dir}"
  context::set "runtime_cri_dockerd_node_dir" "${cluster_dir}/${node_name}"
  context::set "runtime_cri_dockerd_bin_dir" "${cluster_dir}/${node_name}/cri-dockerd"
}

step::runtime.cri.dockerd.collect.paths::rollback() { return 0; }

step::runtime.cri.dockerd.collect.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}