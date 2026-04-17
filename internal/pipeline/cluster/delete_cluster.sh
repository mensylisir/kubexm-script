#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Delete Cluster Pipeline
# ==============================================================================
# 编排组件模块执行集群删除：
# 1. 预检查 - 验证集群状态
# 2. 清理工作负载
# 3. 删除 Addons
# 4. 删除网络组件 (CNI)
# 5. 删除 etcd
# 6. 清理 /etc/hosts
# 7. 清理 K8s 组件 (kubelet, kubeadm reset)
# 8. 清理运行时
# ==============================================================================

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/module/addons.sh"
source "${KUBEXM_ROOT}/internal/module/cni.sh"
source "${KUBEXM_ROOT}/internal/module/etcd.sh"
source "${KUBEXM_ROOT}/internal/module/os.sh"
source "${KUBEXM_ROOT}/internal/module/runtime.sh"
source "${KUBEXM_ROOT}/internal/task/common/validate.sh"
source "${KUBEXM_ROOT}/internal/task/remove.sh"
source "${KUBEXM_ROOT}/internal/task/hosts/cleanup.sh"
source "${KUBEXM_ROOT}/internal/task/kubeadm/remove.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"

# ==============================================================================
# 删除流程编排
# ==============================================================================

pipeline::delete_precheck() {
  local ctx="${1:-}"
  module::preflight_connectivity_permissive "${ctx}" "$@" || return $?
  task::cluster::validate "${ctx}" "$@"
}

pipeline::delete_workloads() {
  local ctx="${1:-}"
  task::cluster::workloads::remove "${ctx}" "$@"
}

pipeline::delete_addons() {
  local ctx="${1:-}"
  module::addons_delete "${ctx}" "$@"
}

pipeline::delete_network() {
  local ctx="${1:-}"
  module::cni_delete "${ctx}" "$@"
}

pipeline::delete_etcd() {
  local ctx="${1:-}"
  module::etcd_delete "${ctx}" "$@"
}

pipeline::delete_hosts() {
  local ctx="${1:-}"
  task::hosts::cleanup "${ctx}" "$@"
}

pipeline::delete_kubernetes() {
  local ctx="${1:-}"
  # 调用 task 而非 module，因为 kubernetes/kubeadm 模块没有 ::delete() 包装
  task::kubelet::remove "${ctx}" "$@"
  task::kubeadm::reset "${ctx}" "$@"
}

pipeline::delete_runtime() {
  local ctx="${1:-}"
  module::runtime_delete "${ctx}" "$@"
}

pipeline::delete_cluster() {
  local ctx="${1:-}"

  # Initialize progress tracking (8 steps)
  pipeline::init_progress 8

  logger::warn "═══════════════════════════════════════════════════════"
  logger::warn "WARNING: This operation will IRREVERSIBLY delete the cluster!"
  logger::warn "All data, configurations, and workloads will be permanently lost."
  logger::warn "═══════════════════════════════════════════════════════"

  pipeline::step_start "PreDelete"
  logger::info "[Pipeline:delete] PreDelete: validating cluster state..."
  pipeline::delete_precheck "${ctx}" "$@" || { pipeline::step_fail "PreDelete"; return $?; }
  pipeline::step_complete "PreDelete"

  pipeline::step_start "WorkloadCleanup"
  logger::info "[Pipeline:delete] WorkloadCleanup: removing workloads..."
  pipeline::delete_workloads "${ctx}" "$@" || { pipeline::step_fail "WorkloadCleanup"; return $?; }
  pipeline::step_complete "WorkloadCleanup"

  pipeline::step_start "AddonsDelete"
  logger::info "[Pipeline:delete] AddonsDelete: removing addons..."
  pipeline::delete_addons "${ctx}" "$@" || { pipeline::step_fail "AddonsDelete"; return $?; }
  pipeline::step_complete "AddonsDelete"

  pipeline::step_start "NetworkDelete"
  logger::info "[Pipeline:delete] NetworkDelete: removing network components..."
  pipeline::delete_network "${ctx}" "$@" || { pipeline::step_fail "NetworkDelete"; return $?; }
  pipeline::step_complete "NetworkDelete"

  pipeline::step_start "EtcdDelete"
  logger::info "[Pipeline:delete] EtcdDelete: stopping and cleaning up etcd..."
  pipeline::delete_etcd "${ctx}" "$@" || { pipeline::step_fail "EtcdDelete"; return $?; }
  pipeline::step_complete "EtcdDelete"

  pipeline::step_start "HostsCleanup"
  logger::info "[Pipeline:delete] HostsCleanup: cleaning up /etc/hosts..."
  pipeline::delete_hosts "${ctx}" "$@" || { pipeline::step_fail "HostsCleanup"; return $?; }
  pipeline::step_complete "HostsCleanup"

  pipeline::step_start "KubernetesTeardown"
  logger::info "[Pipeline:delete] KubernetesTeardown: cleaning up K8s components..."
  pipeline::delete_kubernetes "${ctx}" "$@" || { pipeline::step_fail "KubernetesTeardown"; return $?; }
  pipeline::step_complete "KubernetesTeardown"

  pipeline::step_start "RuntimeCleanup"
  logger::info "[Pipeline:delete] RuntimeCleanup: cleaning up runtime..."
  pipeline::delete_runtime "${ctx}" "$@" || { pipeline::step_fail "RuntimeCleanup"; return $?; }
  pipeline::step_complete "RuntimeCleanup"

  pipeline::summary
  logger::info "[Pipeline:delete] Delete completed successfully!"
  return 0
}

pipeline::delete_cluster_main() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="delete.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning delete cluster pipeline"
    return 0
  fi

  # ============================================================================
  # 参数解析
  # ============================================================================
  local cluster_name=""
  local force="false"
  local backup_path=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --force)
        force="true"
        ;;
      --backup=*)
        backup_path="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for delete cluster"
    return 2
  fi

  # ============================================================================
  # 环境准备
  # ============================================================================
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  
  # 强制更新配置文件路径（因为KUBEXM_CLUSTER_NAME刚刚设置）
  KUBEXM_CONFIG_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/config.yaml"
  KUBEXM_HOST_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/host.yaml"
  export KUBEXM_CONFIG_FILE KUBEXM_HOST_FILE
  if [[ ! -f "${KUBEXM_CONFIG_FILE}" ]]; then
    logger::error "config.yaml not found: ${KUBEXM_CONFIG_FILE}"
    return 1
  fi
  if [[ ! -f "${KUBEXM_HOST_FILE}" ]]; then
    logger::error "host.yaml not found: ${KUBEXM_HOST_FILE}"
    return 1
  fi
  parser::load_config
  parser::load_hosts

  # ============================================================================
  # 确认删除（除非 --force）
  # ============================================================================
  if [[ "${force}" != "true" ]]; then
    logger::warn "Cluster deletion is irreversible!"
    if [[ -t 0 ]]; then
      local confirm=""
      logger::warn "Type 'yes' to confirm deletion, or use --force to skip confirmation:"
      read -r confirm || return 3
      if [[ "${confirm}" != "yes" ]]; then
        logger::info "Deletion cancelled."
        return 3
      fi
    else
      logger::warn "Running in non-interactive mode. Use --force to skip confirmation."
      return 3
    fi
  fi

  # ============================================================================
  # 预删除备份（如果指定了 --backup）
  # ============================================================================
  if [[ -n "${backup_path}" ]]; then
    logger::info "Creating pre-delete backup to: ${backup_path}"
    
    # Source etcd module for backup
    source "${KUBEXM_ROOT}/internal/module/etcd.sh"
    
    export KUBEXM_BACKUP_PATH="${backup_path}"
    if ! module::etcd_backup "${ctx}" "--path=${backup_path}"; then
      logger::error "Pre-delete backup failed!"
      logger::error "Aborting deletion to prevent data loss."
      logger::error "Please fix backup issues or omit --backup flag to delete without backup."
      return 1
    fi
    
    logger::info "Pre-delete backup completed successfully"
    logger::info "Backup location: ${backup_path}"
  fi

  # ============================================================================
  # 获取集群锁 + 启动超时监控（防止并发操作同一集群）
  # ============================================================================
  pipeline::start_timeout_watchdog
  pipeline::acquire_lock "${cluster_name}" 300 || { pipeline::stop_timeout_watchdog; return 1; }
  trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog; pipeline::_rollback_all' EXIT

  # ============================================================================
  # 执行删除流程
  # ============================================================================
  pipeline::delete_cluster "${ctx}" "$@"

  # 成功完成，清空回滚栈，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  logger::info "[Pipeline:delete] Cluster deleted successfully!"
  return 0
}