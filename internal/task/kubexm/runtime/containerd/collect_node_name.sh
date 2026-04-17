#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.containerd.collect.node.name::check() { return 1; }

step::cluster.install.runtime.containerd.collect.node.name::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"

  local node_name
  node_name=$(identity::resolve_node_name)

  context::set "runtime_containerd_node_name" "${node_name}"
}

step::cluster.install.runtime.containerd.collect.node.name::rollback() { return 0; }

step::cluster.install.runtime.containerd.collect.node.name::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
