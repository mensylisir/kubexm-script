#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Upgrade Pre-Backup Task
# ==============================================================================
# 升级前自动创建 etcd 快照备份
# ==============================================================================

task::upgrade_precheck::backup() {
  local ctx="$1"
  shift
  _="${ctx}" # context passed for consistency with other task signatures
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  log::info "=== Creating pre-upgrade etcd backup ==="

  local etcd_type etcd_cert_dir backup_dir etcd_nodes
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  backup_dir="/var/backups/etcd"
  if [[ "${etcd_type}" == "kubexm" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  else
    etcd_cert_dir="/etc/kubernetes/pki/etcd"
  fi

  # 获取第一个 etcd 节点执行备份
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane')
  local first_node
  first_node=$(echo "${etcd_nodes}" | head -1)
  if [[ -z "${first_node}" ]]; then
    log::warn "No etcd/control-plane nodes found, skipping backup"
    return 0
  fi

  local first_ip
  first_ip=$(config::get_host_param "${first_node}" "address")
  if [[ -z "${first_ip}" ]]; then
    log::warn "Cannot get IP for etcd node ${first_node}, skipping backup"
    return 0
  fi

  # 在当前 context 下执行远程备份（使用 KUBEXM_HOST 切换）
  local orig_host="${KUBEXM_HOST}"
  export KUBEXM_HOST="${first_ip}"

  local timestamp snapshot_path
  timestamp=$(date +%Y%m%d-%H%M%S)
  snapshot_path="${backup_dir}/etcd-snapshot-preupgrade-${timestamp}.db"

  local backup_cmd="mkdir -p ${backup_dir} && ETCDCTL_API=3 etcdctl snapshot save ${snapshot_path} --endpoints=https://127.0.0.1:2379 --cacert=${etcd_cert_dir}/ca.crt --cert=${etcd_cert_dir}/server.crt --key=${etcd_cert_dir}/server.key"

  # 通过 SSH 远程执行备份
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"${first_ip}" "${backup_cmd}" || {
    log::error "Failed to create etcd backup on ${first_ip}"
    export KUBEXM_HOST="${orig_host}"
    return 1
  }

  log::info "Pre-upgrade etcd backup created: ${snapshot_path}"
  export KUBEXM_HOST="${orig_host}"
  return 0
}

export -f task::upgrade_precheck::backup
