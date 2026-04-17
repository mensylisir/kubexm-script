#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.kubeconfig.files::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/admin.conf"; then
    return 0
  fi
  return 1
}

step::kubernetes.distribute.kubeconfig.files::run() {
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
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local node_name=""
  local node
  for node in $(config::get_all_host_names); do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  if [[ -z "${node_name}" ]]; then
    node_name="${KUBEXM_HOST}"
  fi

  local kube_dir
  kube_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/kubeconfig"
  if [[ ! -d "${kube_dir}" ]]; then
    log::error "Missing kubeconfig dir for ${node_name}: ${kube_dir}"
    return 1
  fi

  runner::remote_exec "mkdir -p /etc/kubernetes"

  local file
  for file in "${kube_dir}"/*; do
    [[ -f "${file}" ]] || continue
    runner::remote_copy_file "${file}" "/etc/kubernetes/$(basename "${file}")"
  done
}

step::kubernetes.distribute.kubeconfig.files::rollback() { return 0; }

step::kubernetes.distribute.kubeconfig.files::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
