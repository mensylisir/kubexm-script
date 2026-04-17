#!/usr/bin/env bash
set -euo pipefail

step::etcd.upgrade.copy.binaries::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # Check if etcd is NOT running - binaries should only be copied when etcd is stopped for upgrade
  if step::check::remote_service_running "${KUBEXM_HOST}" "etcd"; then
    return 0  # etcd is running, skip copy (upgrade should stop it first)
  fi
  return 1  # etcd is stopped, proceed with copy
}

step::etcd.upgrade.copy.binaries::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local etcd_bin etcdctl_bin
  etcd_bin="$(context::get "etcd_upgrade_bin" || true)"
  etcdctl_bin="$(context::get "etcd_upgrade_ctl_bin" || true)"

  runner::remote_copy_file "${etcd_bin}" "/usr/local/bin/etcd"
  if [[ -f "${etcdctl_bin}" ]]; then
    runner::remote_copy_file "${etcdctl_bin}" "/usr/local/bin/etcdctl"
  fi
  runner::remote_exec "chmod +x /usr/local/bin/etcd /usr/local/bin/etcdctl"
}

step::etcd.upgrade.copy.binaries::rollback() { return 0; }

step::etcd.upgrade.copy.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}
