#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.defaults.storage::check() { return 1; }

step::manifests.show.defaults.storage::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  echo "  存储配置:"
  echo "    - 临时存储: $(defaults::get_storage_temp)"
  echo "    - 持久化存储: $(defaults::get_storage_persistent) (默认)"
  echo
}

step::manifests.show.defaults.storage::rollback() { return 0; }

step::manifests.show.defaults.storage::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
