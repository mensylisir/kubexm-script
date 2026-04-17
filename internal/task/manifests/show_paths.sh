#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.paths::check() { return 1; }

step::manifests.show.paths::run() {
  local ctx="$1"
  shift

  echo "=== 包存储路径 ==="
  echo "  二进制包: packages/{component}/{version}/{arch}/"
  echo "  镜像: packages/images/"
  echo "  Helm包: packages/helm/{chart}/{version}/"
  echo "  系统包: packages/iso/{os}/{version}/{arch}/"
  echo "  节点配置: packages/{cluster}/{node}/"
}

step::manifests.show.paths::rollback() { return 0; }

step::manifests.show.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
