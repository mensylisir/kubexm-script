#!/usr/bin/env bash
set -euo pipefail

step::etcd.copy.certs.permissions::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # Check if all expected cert files exist on remote - if they do, permissions need to be set
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/etcd/ssl/ca.crt" &&
     step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/etcd/ssl/peer.crt" &&
     step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/etcd/ssl/peer.key"; then
    return 1  # Files exist, need to set permissions
  fi
  return 0  # No certs to set permissions on
}

step::etcd.copy.certs.permissions::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "chmod 644 /etc/etcd/ssl/*.crt && chmod 600 /etc/etcd/ssl/*.key"
}

step::etcd.copy.certs.permissions::rollback() { return 0; }

step::etcd.copy.certs.permissions::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
