#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/module/etcd.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"

pipeline::backup_cluster() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="backup.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning backup cluster pipeline"
    return 0
  fi

  local cluster_name=""
  local backup_path=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --path=*)
        backup_path="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for backup cluster"
    return 2
  fi

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

  # 如果指定了 --path，设置到 context 供 step 使用
  if [[ -n "${backup_path}" ]]; then
    context::set "etcd_backup_path" "${backup_path}" 2>/dev/null || true
    export KUBEXM_BACKUP_PATH="${backup_path}"
  fi

  # 获取集群锁 + 启动超时监控
  pipeline::start_timeout_watchdog
  pipeline::acquire_lock "${cluster_name}" 300 || { pipeline::stop_timeout_watchdog; return 1; }
  trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog' EXIT

  module::preflight_connectivity_permissive "${ctx}" "$@" || return $?

  # Initialize progress tracking (1 step)
  pipeline::init_progress 1

  pipeline::step_start "EtcdBackup"
  logger::info "[Pipeline] Starting etcd backup..."
  module::etcd_backup "${ctx}" "$@" || { pipeline::step_fail "EtcdBackup"; return $?; }
  pipeline::step_complete "EtcdBackup"

  # 成功完成，清空回滚栈，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  pipeline::summary
  logger::info "[Pipeline:backup] Cluster backup completed successfully!"
  return 0
}