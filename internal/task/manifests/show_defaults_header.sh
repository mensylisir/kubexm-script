#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.defaults.header::check() { return 1; }

step::manifests.show.defaults.header::run() {
  local ctx="$1"
  shift

  echo "=== 默认配置 ==="
}

step::manifests.show.defaults.header::rollback() { return 0; }

step::manifests.show.defaults.header::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
