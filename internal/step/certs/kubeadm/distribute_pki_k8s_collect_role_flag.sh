#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.pki.k8s.collect.role.flag::check() { return 1; }

step::kubernetes.distribute.pki.k8s.collect.role.flag::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local node_name
  node_name=$(context::get "kubernetes_pki_node_name")

  local control_plane_nodes
  control_plane_nodes=$(config::get_role_members 'control-plane')
  local is_control_plane="false"
  if echo " ${control_plane_nodes} " | grep -qw " ${node_name} "; then
    is_control_plane="true"
  fi

  context::set "kubernetes_pki_is_control_plane" "${is_control_plane}"
}

step::kubernetes.distribute.pki.k8s.collect.role.flag::rollback() { return 0; }

step::kubernetes.distribute.pki.k8s.collect.role.flag::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
