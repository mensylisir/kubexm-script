#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.binaries.kubexm.collect.cluster.name::check() { return 1; }

step::kubernetes.distribute.binaries.kubexm.collect.cluster.name::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"

  local cluster_name
  cluster_name=$(identity::require_cluster_name "$@")

  context::set "kubernetes_kubexm_binaries_cluster_name" "${cluster_name}"
}

step::kubernetes.distribute.binaries.kubexm.collect.cluster.name::rollback() { return 0; }

step::kubernetes.distribute.binaries.kubexm.collect.cluster.name::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
