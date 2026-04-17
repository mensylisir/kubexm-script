#!/usr/bin/env bash
set -euo pipefail

step::cluster.cleanup.pki.dir::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # 如果节点不可达，跳过
  if ! step::check::host_reachable 5; then
    return 0
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/etc/kubernetes/pki"; then
    return 1
  fi
  return 0
}

step::cluster.cleanup.pki.dir::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Cleaning Kubernetes PKI dir on ${KUBEXM_HOST}..."
  runner::remote_exec "rm -rf /etc/kubernetes/pki >/dev/null 2>&1 || true"
}

step::cluster.cleanup.pki.dir::rollback() { return 0; }

step::cluster.cleanup.pki.dir::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
