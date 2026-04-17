#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Addon Task - certificate auto renew
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::install_cert_auto_renew() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.setup.cert.auto.renew:${KUBEXM_ROOT}/internal/task/common/setup_cert_auto_renew.sh"
}

task::delete_cert_auto_renew() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.delete.cert.auto.renew:${KUBEXM_ROOT}/internal/task/common/delete_cert_auto_renew.sh"
}

export -f task::install_cert_auto_renew
export -f task::delete_cert_auto_renew