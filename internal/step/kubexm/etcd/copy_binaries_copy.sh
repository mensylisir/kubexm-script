#!/usr/bin/env bash
set -euo pipefail

step::etcd.copy.binaries.copy::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "etcd" 2>/dev/null; then
    return 1
  fi

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "etcdctl" 2>/dev/null; then
    return 1
  fi

  return 0
}

step::etcd.copy.binaries.copy::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local etcd_bin_dir
  etcd_bin_dir="$(context::get "etcd_binaries_dir" || true)"

  for bin in etcd etcdctl etcdutl; do
    if [[ -f "${etcd_bin_dir}/${bin}" ]]; then
      runner::remote_copy_file "${etcd_bin_dir}/${bin}" "/usr/local/bin/${bin}"
      runner::remote_exec "chmod +x /usr/local/bin/${bin}"
    fi
  done
}

step::etcd.copy.binaries.copy::rollback() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "rm -f /usr/local/bin/etcd /usr/local/bin/etcdctl /usr/local/bin/etcdutl 2>/dev/null || true"
}

step::etcd.copy.binaries.copy::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
