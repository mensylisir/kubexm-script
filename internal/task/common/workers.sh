#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kubernetes Task - Workers Deploy (kubexm binary deployment)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/common/kubelet.sh"
source "${KUBEXM_ROOT}/internal/task/common/kube_proxy.sh"

# Full kubexm Workers deploy flow
task::kubexm_deploy_workers() {
  local ctx="$1"
  shift
  task::kubexm_install_kubelet "${ctx}" "$@"
  task::kubexm_install_kube_proxy "${ctx}" "$@"
}

export -f task::kubexm_deploy_workers