#!/usr/bin/env bash
set -euo pipefail

step::certs.renew.etcd.certs::check() { return 1; }

step::certs.renew.etcd.certs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/certs_renew.sh"
  certs::renew "etcd" "$@"
}

step::certs.renew.etcd.certs::rollback() { return 0; }

step::certs.renew.etcd.certs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
