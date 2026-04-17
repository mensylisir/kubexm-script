#!/usr/bin/env bash
set -euo pipefail

step::images.push.collect.flags.unknown::check() { return 1; }

step::images.push.collect.flags.unknown::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cluster=*|--list=*|--dual|--manifest|--target-registry=*|--packages|--packages-dir=*|--parallel=*|-h|--help)
        ;;
      *)
        log::error "未知参数: $1"
        return 1
        ;;
    esac
    shift
  done
}

step::images.push.collect.flags.unknown::rollback() { return 0; }

step::images.push.collect.flags.unknown::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
