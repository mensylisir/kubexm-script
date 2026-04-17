#!/usr/bin/env bash
set -euo pipefail

step::etcd.upgrade.validate::check() { return 1; }

step::etcd.upgrade.validate::run() {
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
    echo "missing required --to-version for upgrade etcd" >&2
    return 2
  fi
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local etcd_type
  etcd_type=$(config::get_etcd_type)
  if [[ "${etcd_type}" == "exists" ]]; then
    log::error "etcd_type=exists does not support automatic upgrade"
    return 1
  fi

  local etcd_nodes
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane')
  if [[ -z "${etcd_nodes}" ]]; then
    log::error "No etcd nodes found"
    return 1
  fi
}

step::etcd.upgrade.validate::rollback() { return 0; }

step::etcd.upgrade.validate::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
