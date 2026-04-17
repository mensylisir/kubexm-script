#!/usr/bin/env bash
set -euo pipefail

step::etcd.upgrade.backup::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "etcd" 2>/dev/null; then
    return 1
  fi
  return 0
}

step::etcd.upgrade.backup::run() {
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
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Backing up etcd on ${KUBEXM_HOST}..."
  local etcd_type etcd_cert_dir backup_dir
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  backup_dir="/var/backups/etcd"
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  local backup_cmd="mkdir -p ${backup_dir} && ETCDCTL_API=3 etcdctl snapshot save ${backup_dir}/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db --endpoints=https://127.0.0.1:2379 --cacert=${etcd_cert_dir}/ca.crt --cert=${etcd_cert_dir}/server.crt --key=${etcd_cert_dir}/server.key"
  runner::remote_exec "${backup_cmd}" || { log::error "etcd backup failed on ${KUBEXM_HOST}"; return 1; }
  log::info "Etcd backup completed on ${KUBEXM_HOST}"
}

step::etcd.upgrade.backup::rollback() { return 0; }

step::etcd.upgrade.backup::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local etcd_nodes _etcd_result
  _etcd_result=$(config::get_role_members 'etcd' 2>/dev/null || true)
  if [[ -z "${_etcd_result}" ]]; then
    etcd_nodes=$(config::get_role_members 'control-plane')
  else
    etcd_nodes="${_etcd_result}"
  fi
  local first_node
  first_node=$(echo "${etcd_nodes}" | head -1)
  if [[ -z "${first_node}" ]]; then
    return 0
  fi
  local first_ip
  first_ip=$(config::get_host_param "${first_node}" "address")
  [[ -n "${first_ip}" ]] && echo "${first_ip}"
}
