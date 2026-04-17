#!/usr/bin/env bash
set -euo pipefail

step::certs.renew.kubernetes.ca::check() { return 1; }

step::certs.renew.kubernetes.ca::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/certs_renew.sh"
  certs::renew "kubernetes" "$@"
}

step::certs.renew.kubernetes.ca::rollback() { return 0; }

step::certs.renew.kubernetes.ca::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
