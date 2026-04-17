#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/module/etcd.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"

pipeline::restore_cluster() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="restore.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning restore cluster pipeline"
    return 0
  fi

  local cluster_name=""
  local backup_path=""
  local force="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --path=*)
        backup_path="${arg#*=}"
        ;;
      --force)
        force="true"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for restore cluster"
    return 2
  fi
  if [[ -z "${backup_path}" ]]; then
    logger::error "missing required --path for restore cluster"
    return 2
  fi

  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  
  # 强制更新配置文件路径（因为KUBEXM_CLUSTER_NAME刚刚设置）
  KUBEXM_CONFIG_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/config.yaml"
  KUBEXM_HOST_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/host.yaml"
  export KUBEXM_CONFIG_FILE KUBEXM_HOST_FILE
  # 将 --path 传递给下游 step
  export KUBEXM_RESTORE_PATH="${backup_path}"
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
  # 配置验证（恢复前验证配置一致性）
  # ============================================================================
  logger::info "[Pipeline] Validating configuration consistency..."
  config::validate_consistency || {
    logger::error "Configuration validation failed. Aborting restore."
    return 1
  }

  # 验证备份文件存在
  if [[ ! -f "${backup_path}" ]]; then
    logger::error "backup file not found: ${backup_path}"
    return 1
  fi

  module::preflight_connectivity_permissive "${ctx}" "$@" || {
    logger::error "Preflight connectivity check failed. Cannot proceed with restore."
    return $?
  }

  # 恢复是高危操作，需要确认
  if [[ "${force}" != "true" ]]; then
    logger::warn "Cluster restore is IRREVERSIBLE! Current etcd data will be overwritten."
    logger::warn "Backup source: ${backup_path}"
    if [[ -t 0 ]]; then
      local confirm=""
      logger::warn "Type 'yes' to confirm restore:"
      read -r confirm || return 3
      if [[ "${confirm}" != "yes" ]]; then
        logger::info "Restore cancelled."
        return 3
      fi
    else
      logger::warn "Non-interactive mode. Use --force to skip confirmation."
      return 3
    fi
  fi

  # Initialize progress tracking (1 step)
  pipeline::init_progress 1

  # 获取集群锁 + 启动超时监控
  pipeline::start_timeout_watchdog
  pipeline::acquire_lock "${cluster_name}" 600 || { pipeline::stop_timeout_watchdog; return 1; }
  trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog' EXIT

  pipeline::step_start "EtcdRestore"
  logger::info "[Pipeline] Starting etcd restore..."
  module::etcd_restore "${ctx}" "$@" || { pipeline::step_fail "EtcdRestore"; return $?; }
  pipeline::step_complete "EtcdRestore"

  # 成功完成，清空回滚栈，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  pipeline::summary
  logger::info "[Pipeline:restore] Cluster restore completed successfully!"
  return 0
}