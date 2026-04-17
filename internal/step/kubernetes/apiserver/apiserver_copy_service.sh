#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.apiserver.copy.service::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/systemd/system/kube-apiserver.service"
}

step::kubernetes.apiserver.copy.service::run() {
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

  local service_file="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/kube-apiserver/kube-apiserver.service"
  if [[ ! -f "${service_file}" ]]; then
    log::error "Missing kube-apiserver service file: ${service_file}"
    return 1
  fi

  runner::remote_copy_file "${service_file}" "/etc/systemd/system/kube-apiserver.service"

  # 复制 audit policy 和 encryption config（生产必需）
  local packages_base="${KUBEXM_ROOT}/packages/${cluster_name}"
  if [[ -f "${packages_base}/audit-policy.yaml" ]]; then
    runner::remote_exec "mkdir -p /etc/kubernetes"
    runner::remote_copy_file "${packages_base}/audit-policy.yaml" "/etc/kubernetes/audit-policy.yaml"
    log::info "Audit policy deployed to ${KUBEXM_HOST}"
  fi
  if [[ -f "${packages_base}/encryption-config.yaml" ]]; then
    runner::remote_exec "mkdir -p /etc/kubernetes"
    runner::remote_copy_file "${packages_base}/encryption-config.yaml" "/etc/kubernetes/encryption-config.yaml"
    runner::remote_exec "chmod 600 /etc/kubernetes/encryption-config.yaml"
    log::info "Encryption config deployed to ${KUBEXM_HOST}"
  fi
}

step::kubernetes.apiserver.copy.service::rollback() { return 0; }

step::kubernetes.apiserver.copy.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
