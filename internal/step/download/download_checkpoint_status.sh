#!/usr/bin/env bash
set -euo pipefail

step::download.checkpoint.status::check() { return 1; }

step::download.checkpoint.status::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::status
}

step::download.checkpoint.status::rollback() { return 0; }

step::download.checkpoint.status::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
