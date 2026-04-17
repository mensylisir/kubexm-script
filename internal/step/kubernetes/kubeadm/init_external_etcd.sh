#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.init.external.etcd::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::remote_exec "test -f /etc/kubernetes/admin.conf"
}

step::kubeadm.init.external.etcd::run() {
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
  source "${KUBEXM_ROOT}/internal/utils/kubeadm_config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local first_master
  first_master=$(config::get_role_members 'control-plane' | awk '{print $1}')
  if [[ -z "${first_master}" ]]; then
    log::error "No control-plane node found"
    return 1
  fi

  local packages_dir
  packages_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${first_master}"
  mkdir -p "${packages_dir}" || { log::error "Failed to create packages directory: ${packages_dir}"; return 1; }

  local config_file
  config_file="${packages_dir}/kubeadm-config.yaml"
  kubeadm::generate_external_etcd_config "${config_file}" || { log::error "Failed to generate external etcd kubeadm config"; return 1; }
  kubeadm::generate_audit_policy "${packages_dir}" || { log::error "Failed to generate audit policy"; return 1; }
  kubeadm::generate_encryption_config "${packages_dir}" || { log::error "Failed to generate encryption config"; return 1; }

  runner::remote_exec "mkdir -p /etc/kubernetes /var/log/kubernetes" || { log::error "Failed to create /etc/kubernetes on ${KUBEXM_HOST}"; return 1; }
  runner::remote_copy_file "${config_file}" "/etc/kubernetes/kubeadm-config.yaml" || { log::error "Failed to copy kubeadm config to ${KUBEXM_HOST}"; return 1; }
  if [[ -f "${packages_dir}/audit-policy.yaml" ]]; then
    runner::remote_copy_file "${packages_dir}/audit-policy.yaml" "/etc/kubernetes/audit-policy.yaml"
    log::info "Audit policy deployed to ${KUBEXM_HOST}"
  fi
  if [[ -f "${packages_dir}/encryption-config.yaml" ]]; then
    runner::remote_copy_file "${packages_dir}/encryption-config.yaml" "/etc/kubernetes/encryption-config.yaml"
    runner::remote_exec "chmod 600 /etc/kubernetes/encryption-config.yaml"
    log::info "Encryption config deployed to ${KUBEXM_HOST}"
  fi

  runner::remote_exec "kubeadm init --config /etc/kubernetes/kubeadm-config.yaml" || { log::error "kubeadm init failed on ${KUBEXM_HOST}"; return 1; }

  # 验证控制面组件是否正常启动
  log::info "Verifying control plane components..."
  local wait_count=0
  while [[ ${wait_count} -lt 30 ]]; do
    local apiserver_ready
    apiserver_ready=$(runner::remote_exec "kubectl get pods -n kube-system -l component=kube-apiserver --no-headers 2>/dev/null | grep -c Running || true" || echo "0")
    if [[ "${apiserver_ready}" -ge 1 ]]; then
      log::info "Control plane is running"
      break
    fi
    wait_count=$((wait_count + 1))
    sleep 2
  done

  runner::remote_exec "mkdir -p /root/.kube && cp /etc/kubernetes/admin.conf /root/.kube/config" || { log::error "Failed to copy kubeconfig on ${KUBEXM_HOST}"; return 1; }
  log::info "kubeadm external etcd init completed on ${KUBEXM_HOST}"
}

step::kubeadm.init.external.etcd::rollback() { return 0; }

step::kubeadm.init.external.etcd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
