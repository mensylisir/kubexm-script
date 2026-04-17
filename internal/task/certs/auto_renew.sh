#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Certs Task - Certificate Auto Renew
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# 证书自动续期配置
task::setup_cert_auto_renew() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.setup.cert.auto.renew:${KUBEXM_ROOT}/internal/task/common/setup_cert_auto_renew.sh"
}

export -f task::setup_cert_auto_renew