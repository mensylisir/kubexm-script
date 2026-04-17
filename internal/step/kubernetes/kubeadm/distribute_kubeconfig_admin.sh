#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.kubeconfig.admin::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/admin.conf"
}

step::kubernetes.distribute.kubeconfig.admin::run() {
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

  if [[ -f "${kube_dir}/admin.conf" ]]; then
    runner::remote_copy_file "${kube_dir}/admin.conf" "/etc/kubernetes/admin.conf"
  elif [[ -f "${kube_dir}/admin.kubeconfig" ]]; then
    runner::remote_copy_file "${kube_dir}/admin.kubeconfig" "/etc/kubernetes/admin.conf"
  fi
}

step::kubernetes.distribute.kubeconfig.admin::rollback() { return 0; }

step::kubernetes.distribute.kubeconfig.admin::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
