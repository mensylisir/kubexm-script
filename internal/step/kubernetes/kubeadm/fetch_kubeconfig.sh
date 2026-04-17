#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.fetch.kubeconfig::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/admin.conf"
}

step::kubeadm.fetch.kubeconfig::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*) cluster_name="${arg#*=}" ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local dest_dir
  dest_dir="${KUBEXM_ROOT}/packages/${cluster_name}/kubeconfig"
  mkdir -p "${dest_dir}"

  local dest_file
  dest_file="${dest_dir}/admin.conf"

  runner::remote_copy_from "/etc/kubernetes/admin.conf" "${dest_file}"
  export KUBECONFIG="${dest_file}"
}

step::kubeadm.fetch.kubeconfig::rollback() { return 0; }

step::kubeadm.fetch.kubeconfig::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
