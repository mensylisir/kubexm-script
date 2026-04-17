#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Runtime Task - Remove
# ==============================================================================
# Unified dispatcher for runtime removal
# Delegates to component-specific delete functions
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# Source individual runtime delete functions
source "${KUBEXM_ROOT}/internal/task/runtime/containerd.sh"
source "${KUBEXM_ROOT}/internal/task/runtime/docker.sh"
source "${KUBEXM_ROOT}/internal/task/runtime/crio.sh"
source "${KUBEXM_ROOT}/internal/task/runtime/cri_dockerd.sh"

# -----------------------------------------------------------------------------
# Unified runtime removal dispatcher
# -----------------------------------------------------------------------------
task::runtime::remove() {
  local ctx="$1"
  shift

  local runtime_type
  runtime_type=$(config::get_runtime_type 2>/dev/null || echo "containerd")

  case "${runtime_type}" in
    containerd)   task::delete_containerd "${ctx}" "$@" ;;
    docker)        task::delete_docker "${ctx}" "$@" ;;
    crio)          task::delete_crio "${ctx}" "$@" ;;
    cri_dockerd)   task::delete_cri_dockerd "${ctx}" "$@" ;;
    *)
      logger::warn "Unsupported runtime type for removal: ${runtime_type}"
      return 0
      ;;
  esac
}

export -f task::runtime::remove