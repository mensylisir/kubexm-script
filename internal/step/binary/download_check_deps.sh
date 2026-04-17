#!/usr/bin/env bash
set -euo pipefail

step::download.check.deps::check() {
  # If curl exists, dependencies are satisfied
  if command -v curl >/dev/null 2>&1; then
    return 0  # curl exists, skip
  fi
  return 1  # need to check/install
}

step::download.check.deps::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"

  if ! download::ensure_skopeo; then
    echo "Skopeo未安装，将在下载工具后尝试使用离线二进制" >&2
  fi

  if ! command -v curl &>/dev/null; then
    echo "curl未安装" >&2
    return 1
  fi

  return 0
}

step::download.check.deps::rollback() { return 0; }

step::download.check.deps::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
