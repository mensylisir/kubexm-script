#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.control.plane.collect.target::check() { return 1; }

step::cluster.upgrade.control.plane.collect.target::run() {
  local ctx="$1"
  shift
  local target_version=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --to-version=*) target_version="${arg#*=}" ;;
    esac
  done
  if [[ -z "${target_version}" ]]; then
    echo "missing required --to-version for upgrade cluster" >&2
    return 2
  fi

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  context::set "cluster_upgrade_target_version" "${target_version}"
}

step::cluster.upgrade.control.plane.collect.target::rollback() { return 0; }

step::cluster.upgrade.control.plane.collect.target::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
