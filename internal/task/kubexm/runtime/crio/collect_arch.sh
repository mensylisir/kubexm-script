#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.crio.collect.arch::check() { return 1; }

step::cluster.install.runtime.crio.collect.arch::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"

  local node_name arch
  node_name=$(context::get "runtime_crio_node_name")
  arch=$(identity::resolve_arch "${node_name}")

  context::set "runtime_crio_arch" "${arch}"
}

step::cluster.install.runtime.crio.collect.arch::rollback() { return 0; }

step::cluster.install.runtime.crio.collect.arch::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
