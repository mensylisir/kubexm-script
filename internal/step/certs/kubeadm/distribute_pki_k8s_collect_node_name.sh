#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.pki.k8s.collect.node.name::check() { return 1; }

step::kubernetes.distribute.pki.k8s.collect.node.name::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"

  local node_name
  node_name=$(identity::resolve_node_name)

  context::set "kubernetes_pki_node_name" "${node_name}"
}

step::kubernetes.distribute.pki.k8s.collect.node.name::rollback() { return 0; }

step::kubernetes.distribute.pki.k8s.collect.node.name::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
