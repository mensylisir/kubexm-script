#!/usr/bin/env bash
set -euo pipefail

step::runtime.cri.dockerd.collect.arch::check() { return 1; }

step::runtime.cri.dockerd.collect.arch::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"

  local node_name arch
  node_name=$(context::get "runtime_cri_dockerd_node_name")
  arch=$(identity::resolve_arch "${node_name}")

  context::set "runtime_cri_dockerd_arch" "${arch}"
}

step::runtime.cri.dockerd.collect.arch::rollback() { return 0; }

step::runtime.cri.dockerd.collect.arch::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}