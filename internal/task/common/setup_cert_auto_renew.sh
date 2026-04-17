#!/usr/bin/env bash
set -euo pipefail

step::cluster.setup.cert.auto.renew::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  # Check if the auto-renew timer already exists on remote
  if step::check::remote_command_exists "${KUBEXM_HOST}" "kubexm-cert-renew.timer" 2>/dev/null; then
    return 0  # timer exists, skip
  fi
  return 1  # need to set up auto-renew
}

step::cluster.setup.cert.auto.renew::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/utils/cert-rotation.sh"

  local node_ip="${KUBEXM_HOST}"
  if [[ -z "${node_ip}" ]]; then
    log::error "KUBEXM_HOST is empty"
    return 1
  fi

  local k8s_type
  k8s_type=$(config::get_kubernetes_type)
  rotation::setup_auto_renew "${node_ip}" "${cluster_name}" "${k8s_type}"
}

step::cluster.setup.cert.auto.renew::rollback() { return 0; }

step::cluster.setup.cert.auto.renew::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
