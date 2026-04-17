#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.system.packages.header::check() { return 1; }

step::manifests.show.system.packages.header::run() {
  local ctx="$1"
  shift

  echo "=== 系统依赖包 ==="
  echo "  说明：以下包根据配置条件选择性安装"
  echo "  默认条件：单节点/多节点（非高可用），containerd运行时，calico CNI"
  echo
}

step::manifests.show.system.packages.header::rollback() { return 0; }

step::manifests.show.system.packages.header::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
