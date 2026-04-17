#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cp.join.collect.action::check() { return 1; }

step::cluster.scale.cp.join.collect.action::run() {
  local ctx="$1"
  shift
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  if [[ "${action}" != "scale-out-cp" && "${action}" != "scale-in-cp" ]]; then
    context::set "cluster_scale_cp_skip" "true"
    return 0
  fi
  context::set "cluster_scale_cp_skip" "false"
  context::set "cluster_scale_cp_action" "${action}"
}

step::cluster.scale.cp.join.collect.action::rollback() { return 0; }

step::cluster.scale.cp.join.collect.action::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}