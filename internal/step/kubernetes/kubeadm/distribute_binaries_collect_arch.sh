#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.binaries.kubeadm.collect.arch::check() { return 1; }

step::kubernetes.distribute.binaries.kubeadm.collect.arch::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"

  local node_name arch
  node_name=$(context::get "kubernetes_kubeadm_binaries_node_name")
  arch=$(identity::resolve_arch "${node_name}")

  context::set "kubernetes_kubeadm_binaries_arch" "${arch}"
}

step::kubernetes.distribute.binaries.kubeadm.collect.arch::rollback() { return 0; }

step::kubernetes.distribute.binaries.kubeadm.collect.arch::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
