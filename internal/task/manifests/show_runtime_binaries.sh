#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.runtime.binaries::check() { return 1; }

step::manifests.show.runtime.binaries::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/binary_bom.sh"

  local runtime k8s_version arch
  runtime="$(context::get "manifests_runtime" || true)"
  k8s_version="$(context::get "manifests_k8s_version" || true)"
  arch="$(context::get "manifests_arch" || true)"

  echo "=== 容器运行时二进制文件 ==="
  utils::binary::bom::show_runtime_binaries "$runtime" "$k8s_version" "$arch"
  echo
}

step::manifests.show.runtime.binaries::rollback() { return 0; }

step::manifests.show.runtime.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
