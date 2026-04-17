#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.pki.k8s.permissions::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # Check if PKI directory exists on remote host
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/etc/kubernetes/pki"; then
    return 1  # PKI dir exists, need to set permissions
  fi
  return 0  # PKI dir doesn't exist, skip
}

step::kubernetes.distribute.pki.k8s.permissions::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "chmod 644 /etc/kubernetes/pki/*.crt >/dev/null 2>&1 || true"
  runner::remote_exec "chmod 600 /etc/kubernetes/pki/*.key /etc/kubernetes/pki/*-key.pem >/dev/null 2>&1 || true"
}

step::kubernetes.distribute.pki.k8s.permissions::rollback() { return 0; }

step::kubernetes.distribute.pki.k8s.permissions::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
