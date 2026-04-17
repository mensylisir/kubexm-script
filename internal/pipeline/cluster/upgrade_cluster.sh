#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Upgrade Cluster Pipeline
# ==============================================================================
# 编排集群升级：
# 1. PreUpgrade - 预检查（版本、健康状态）
# 2. ControlPlaneUpgrade - 控制面升级
# 3. WorkersUpgrade - 工作节点升级
# 4. AddonsUpgrade - Addons 升级
# ==============================================================================

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/module/cni.sh"
source "${KUBEXM_ROOT}/internal/task/common/upgrade_cluster.sh"
source "${KUBEXM_ROOT}/internal/task/common/upgrade_check_version.sh"
source "${KUBEXM_ROOT}/internal/task/common/upgrade_backup.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"

# ==============================================================================
# 升级流程编排
# ==============================================================================

pipeline::upgrade_precheck() {
  local ctx="${1:-}"
  module::preflight_connectivity_strict "${ctx}" "$@" || return $?
  # 版本兼容性检查（硬性，不兼容则阻断）
  task::upgrade_check_version "${ctx}" "$@" || return $?
  # 升级前健康检查
  task::upgrade_precheck "${ctx}" "$@"
}

pipeline::upgrade_backup() {
  local ctx="${1:-}"
  logger::info "[Pipeline:upgrade] Creating pre-upgrade backup..."
  
  # Use enhanced backup with force option
  if ! pipeline::ensure_pre_operation_backup "upgrade" "false"; then
    logger::warn "Pre-upgrade backup failed, continuing with caution..."
    logger::warn "WARNING: If upgrade fails, manual recovery may be required"
  fi
  
  # Also register rollback action
  if [[ -n "${KUBEXM_PRE_OPERATION_BACKUP:-}" ]]; then
    pipeline::register_rollback \
      "Restore from pre-upgrade backup" \
      "logger::info 'Restoring from ${KUBEXM_PRE_OPERATION_BACKUP}'; module::etcd_restore --path='${KUBEXM_PRE_OPERATION_BACKUP}' || true"
  fi
}

pipeline::upgrade_control_plane() {
  local ctx="${1:-}"
  task::upgrade_control_plane "${ctx}" "$@"
}

pipeline::upgrade_cni() {
  local ctx="${1:-}"
  module::upgrade_cni "${ctx}" "$@"
}

pipeline::upgrade_workers() {
  local ctx="${1:-}"
  task::upgrade_workers "${ctx}" "$@"
}

pipeline::upgrade_addons() {
  local ctx="${1:-}"
  task::upgrade_addons "${ctx}" "$@"
}

pipeline::post_upgrade_validation() {
  local ctx="${1:-}"
  
  logger::info "[Pipeline:upgrade] Running post-upgrade validation..."
  
  # Run smoke tests to verify cluster health
  if type task::smoke_test &>/dev/null; then
    if task::smoke_test "${ctx}" "$@"; then
      logger::info "[Pipeline:upgrade] Post-upgrade validation PASSED"
      return 0
    else
      logger::error "[Pipeline:upgrade] Post-upgrade validation FAILED!"
      logger::error "[Pipeline:upgrade] Cluster may be in degraded state."
      logger::error "[Pipeline:upgrade] Please check logs and run: kubexm health cluster --cluster=${KUBEXM_CLUSTER_NAME}"
      return 1
    fi
  else
    logger::warn "[Pipeline:upgrade] Smoke test not available, skipping post-upgrade validation"
    return 0
  fi
}

pipeline::upgrade_cluster() {
  local ctx="${1:-}"

  # Initialize progress tracking (7 steps)
  pipeline::init_progress 7

  pipeline::step_start "PreUpgrade"
  logger::info "[Pipeline:upgrade] PreUpgrade: running pre-upgrade checks..."
  pipeline::upgrade_precheck "${ctx}" "$@" || { pipeline::step_fail "PreUpgrade"; return $?; }
  pipeline::step_complete "PreUpgrade"

  pipeline::step_start "Backup"
  logger::info "[Pipeline:upgrade] Backup: creating pre-upgrade backup..."
  pipeline::upgrade_backup "${ctx}" "$@" || {
    logger::error "[Pipeline:upgrade] Pre-upgrade backup FAILED!"
    logger::error "[Pipeline:upgrade] Aborting upgrade for safety. Please fix backup issues and retry."
    pipeline::step_fail "Backup"
    return 1
  }
  pipeline::step_complete "Backup"

  pipeline::step_start "ControlPlane"
  logger::info "[Pipeline:upgrade] ControlPlaneUpgrade: upgrading control plane..."
  pipeline::upgrade_control_plane "${ctx}" "$@" || { pipeline::step_fail "ControlPlane"; return $?; }
  # Register rollback to restore from pre-upgrade backup if available
  if [[ -n "${KUBEXM_PRE_OPERATION_BACKUP:-}" ]]; then
    pipeline::register_rollback \
      "Restore cluster from pre-upgrade backup" \
      "logger::warn 'Rolling back upgrade: restoring from ${KUBEXM_PRE_OPERATION_BACKUP}'; module::etcd_restore '${ctx}' '--path=${KUBEXM_PRE_OPERATION_BACKUP}' --force || logger::warn 'Backup restore failed, manual intervention required'"
  else
    pipeline::register_rollback \
      "Note: No backup available for rollback" \
      "logger::error 'Cannot rollback: no pre-upgrade backup found. Manual downgrade required.'"
  fi
  pipeline::step_complete "ControlPlane"

  pipeline::step_start "CNI"
  logger::info "[Pipeline:upgrade] CNIUpgrade: upgrading CNI..."
  pipeline::upgrade_cni "${ctx}" "$@" || { pipeline::step_fail "CNI"; return $?; }
  pipeline::step_complete "CNI"

  pipeline::step_start "Workers"
  logger::info "[Pipeline:upgrade] WorkersUpgrade: upgrading worker nodes..."
  pipeline::upgrade_workers "${ctx}" "$@" || { pipeline::step_fail "Workers"; return $?; }
  pipeline::step_complete "Workers"

  pipeline::step_start "Addons"
  logger::info "[Pipeline:upgrade] AddonsUpgrade: upgrading addons..."
  pipeline::upgrade_addons "${ctx}" "$@" || { pipeline::step_fail "Addons"; return $?; }
  pipeline::step_complete "Addons"

  pipeline::step_start "PostUpgrade"
  logger::info "[Pipeline:upgrade] PostUpgradeValidation: verifying cluster health..."
  pipeline::post_upgrade_validation "${ctx}" "$@" || {
    pipeline::step_fail "PostUpgrade"
    logger::error "[Pipeline:upgrade] UPGRADE COMPLETED WITH VALIDATION FAILURES!"
    logger::error "[Pipeline:upgrade] Cluster may be unstable. Immediate investigation required!"
    return 1
  }
  pipeline::step_complete "PostUpgrade"

  pipeline::summary
  logger::info "[Pipeline:upgrade] Upgrade completed successfully!"
  return 0
}

pipeline::upgrade_cluster_main() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="upgrade.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning upgrade cluster pipeline"
    return 0
  fi

  # ============================================================================
  # 参数解析
  # ============================================================================
  local cluster_name=""
  local to_version=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --to-version=*)
        to_version="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for upgrade cluster"
    return 2
  fi
  if [[ -z "${to_version}" ]]; then
    logger::error "missing required --to-version for upgrade cluster"
    return 2
  fi

  # 验证版本格式（支持 v1.28.0 或 1.28.0）
  local version_pattern='^v?[0-9]+\.[0-9]+\.[0-9]+$'
  if [[ ! "${to_version}" =~ ${version_pattern} ]]; then
    logger::error "invalid version format: ${to_version}. Expected: v1.28.0 or 1.28.0"
    return 2
  fi
  # 统一去除 v 前缀
  to_version="${to_version#v}"

  # ============================================================================
  # 环境准备
  # ============================================================================
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  
  # 强制更新配置文件路径（因为KUBEXM_CLUSTER_NAME刚刚设置）
  KUBEXM_CONFIG_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/config.yaml"
  KUBEXM_HOST_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/host.yaml"
  export KUBEXM_CONFIG_FILE KUBEXM_HOST_FILE
  export KUBEXM_UPGRADE_TO_VERSION="${to_version}"
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
  # 配置验证（升级前验证配置一致性）
  # ============================================================================
  logger::info "[Pipeline] Validating configuration consistency..."
  config::validate_consistency || {
    logger::error "Configuration validation failed. Aborting upgrade."
    return 1
  }

  # ============================================================================
  # 获取集群锁 + 启动超时监控
  # ============================================================================
  pipeline::start_timeout_watchdog
  pipeline::acquire_lock "${cluster_name}" 600 || { pipeline::stop_timeout_watchdog; return 1; }
  trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog; pipeline::_rollback_all' EXIT

  # ============================================================================
  # 执行升级流程
  # ============================================================================
  pipeline::upgrade_cluster "${ctx}" "$@"

  # 成功完成，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  logger::info "[Pipeline:upgrade] Cluster upgraded successfully!"
  return 0
}