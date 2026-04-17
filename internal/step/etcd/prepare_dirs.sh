#!/usr/bin/env bash
set -euo pipefail

step::etcd.prepare.dirs::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_dir_exists "${KUBEXM_HOST}" "/var/lib/etcd"
}

step::etcd.prepare.dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "mkdir -p /etc/etcd/ssl /var/lib/etcd /usr/local/bin"
}

step::etcd.prepare.dirs::rollback() { return 0; }

step::etcd.prepare.dirs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
