#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.system.packages.storage::check() { return 1; }

step::manifests.show.system.packages.storage::run() {
  local ctx="$1"
  shift

  echo "  存储包（可选，仅在启用外部存储时安装）:"
  echo "    - nfs-utils + iscsi-initiator-utils (CentOS系)"
  echo "    - nfs-common + open-iscsi (Ubuntu/Debian系)"
  echo
}

step::manifests.show.system.packages.storage::rollback() { return 0; }

step::manifests.show.system.packages.storage::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
