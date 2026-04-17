#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CNI Task - Remove
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::cni::remove() {
  local ctx="$1"
  shift
  local cni_plugin
  cni_plugin=$(config::get_network_plugin 2>/dev/null || echo "calico")
  case "${cni_plugin}" in
    calico)
      task::run_steps "${ctx}" "$@" -- \
        "cluster.delete.cni.calico:${KUBEXM_ROOT}/internal/task/common/delete_cni_calico.sh"
      ;;
    flannel)
      task::run_steps "${ctx}" "$@" -- \
        "cluster.delete.cni.flannel:${KUBEXM_ROOT}/internal/task/common/delete_cni_flannel.sh"
      ;;
    cilium)
      task::run_steps "${ctx}" "$@" -- \
        "cluster.delete.cni.cilium:${KUBEXM_ROOT}/internal/task/common/delete_cni_cilium.sh"
      ;;
  esac
}

export -f task::cni::remove