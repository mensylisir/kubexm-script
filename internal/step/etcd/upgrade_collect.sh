#!/usr/bin/env bash
set -euo pipefail

step::etcd.upgrade.collect::check() { return 1; }

step::etcd.upgrade.collect::run() {
  local ctx="$1"
  shift
  local target_version="" cluster_name="${KUBEXM_CLUSTER_NAME:-}"
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
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local node_name=""
  local etcd_nodes node node_ip
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane')
  for node in ${etcd_nodes}; do
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ -n "${node_ip}" && "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  local etcd_bin etcdctl_bin
  etcd_bin="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/etcd/${target_version}/etcd"
  etcdctl_bin="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/etcd/${target_version}/etcdctl"

  if [[ ! -f "${etcd_bin}" ]]; then
    log::error "Etcd binary not found: ${etcd_bin}"
    return 1
  fi

  local etcd_type etcd_cert_dir
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  context::set "etcd_upgrade_target_version" "${target_version}"
  context::set "etcd_upgrade_node_name" "${node_name}"
  context::set "etcd_upgrade_bin" "${etcd_bin}"
  context::set "etcd_upgrade_ctl_bin" "${etcdctl_bin}"
  context::set "etcd_upgrade_cert_dir" "${etcd_cert_dir}"
}

step::etcd.upgrade.collect::rollback() { return 0; }

step::etcd.upgrade.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}
