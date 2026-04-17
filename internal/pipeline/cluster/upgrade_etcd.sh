#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Upgrade ETCD Pipeline
# ==============================================================================
# 编排 ETCD 升级：
# 1. PreUpgrade - 预检查
# 2. ETCDUpgrade - ETCD 升级
# ==============================================================================

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/task/common/upgrade_etcd.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"

# ==============================================================================
# 升级流程编排
# ==============================================================================

pipeline::upgrade_etcd_precheck() {
  local ctx="${1:-}"
  task::upgrade_validate "${ctx}" "$@"
}

pipeline::upgrade_etcd_backup() {
  local ctx="${1:-}"
  task::upgrade_backup "${ctx}" "$@" || {
    logger::warn "ETCD backup failed, continuing with caution..."
  }
}

pipeline::upgrade_etcd_do() {
  local ctx="${1:-}"
  task::upgrade_etcd "${ctx}" "$@"
}

pipeline::post_etcd_upgrade_validation() {
  local ctx="${1:-}"
  
  logger::info "[Pipeline:upgrade_etcd] Running post-upgrade ETCD validation..."
  
  # Verify ETCD cluster health
  if command -v etcdctl &>/dev/null; then
    local endpoint="https://127.0.0.1:2379"
    local cacert="/etc/kubernetes/pki/etcd/ca.crt"
    local cert="/etc/kubernetes/pki/etcd/healthcheck-client.crt"
    local key="/etc/kubernetes/pki/etcd/healthcheck-client.key"
    
    logger::info "Checking ETCD cluster health..."
    if ETCDCTL_API=3 etcdctl endpoint health \
      --endpoints="${endpoint}" \
      --cacert="${cacert}" \
      --cert="${cert}" \
      --key="${key}" 2>/dev/null; then
      
      logger::info "ETCD endpoint health check PASSED"
      
      # Check member list
      logger::info "Checking ETCD member list..."
      local member_count
      member_count=$(ETCDCTL_API=3 etcdctl member list \
        --endpoints="${endpoint}" \
        --cacert="${cacert}" \
        --cert="${cert}" \
        --key="${key}" 2>/dev/null | wc -l)
      
      logger::info "ETCD members found: ${member_count}"
      
      # Check version
      logger::info "Checking ETCD version..."
      local version_output
      if version_output=$(ETCDCTL_API=3 etcdctl version 2>/dev/null); then
        logger::info "ETCD version: ${version_output}"
      fi
      
      logger::info "[Pipeline:upgrade_etcd] Post-upgrade validation PASSED"
      return 0
    else
      logger::error "[Pipeline:upgrade_etcd] ETCD health check FAILED!"
      logger::error "[Pipeline:upgrade_etcd] ETCD cluster may be unhealthy!"
      return 1
    fi
  else
    logger::warn "[Pipeline:upgrade_etcd] etcdctl not found, skipping validation"
    return 0
  fi
}

pipeline::upgrade_etcd() {
  local ctx="${1:-}"

  # Initialize progress tracking (4 steps)
  pipeline::init_progress 4

  pipeline::step_start "PreUpgrade"
  logger::info "[Pipeline:upgrade_etcd] PreUpgrade: running pre-upgrade checks..."
  pipeline::upgrade_etcd_precheck "${ctx}" "$@" || { pipeline::step_fail "PreUpgrade"; return $?; }
  pipeline::step_complete "PreUpgrade"

  pipeline::step_start "Backup"
  logger::info "[Pipeline:upgrade_etcd] Backup: creating pre-upgrade backup..."
  pipeline::upgrade_etcd_backup "${ctx}" "$@" || {
    logger::error "[Pipeline:upgrade_etcd] Pre-upgrade backup FAILED!"
    logger::error "[Pipeline:upgrade_etcd] Aborting upgrade for safety. Please fix backup issues and retry."
    pipeline::step_fail "Backup"
    return 1
  }
  pipeline::step_complete "Backup"

  pipeline::step_start "ETCDUpgrade"
  logger::info "[Pipeline:upgrade_etcd] ETCDUpgrade: upgrading ETCD..."
  pipeline::upgrade_etcd_do "${ctx}" "$@" || { pipeline::step_fail "ETCDUpgrade"; return $?; }
  pipeline::register_rollback \
    "Restore ETCD from backup" \
    "logger::warn 'Manual rollback required: restore ETCD from backup'"
  pipeline::step_complete "ETCDUpgrade"

  pipeline::step_start "PostUpgrade"
  logger::info "[Pipeline:upgrade_etcd] PostUpgradeValidation: verifying ETCD health..."
  pipeline::post_etcd_upgrade_validation "${ctx}" "$@" || {
    pipeline::step_fail "PostUpgrade"
    logger::error "[Pipeline:upgrade_etcd] ETCD UPGRADE COMPLETED WITH VALIDATION FAILURES!"
    logger::error "[Pipeline:upgrade_etcd] ETCD cluster may be unstable. Immediate investigation required!"
    return 1
  }
  pipeline::step_complete "PostUpgrade"

  pipeline::summary
  logger::info "[Pipeline:upgrade_etcd] ETCD upgrade completed successfully!"
  return 0
}

pipeline::upgrade_etcd_main() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="upgrade.etcd"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning upgrade etcd pipeline"
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
    logger::error "missing required --cluster for upgrade etcd"
    return 2
  fi
  if [[ -z "${to_version}" ]]; then
    logger::error "missing required --to-version for upgrade etcd"
    return 2
  fi

  # 验证版本格式
  local version_pattern='^v?[0-9]+\.[0-9]+\.[0-9]+$'
  if [[ ! "${to_version}" =~ ${version_pattern} ]]; then
    logger::error "invalid version format: ${to_version}. Expected: v3.5.13 or 3.5.13"
    return 2
  fi
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
    logger::error "Configuration validation failed. Aborting etcd upgrade."
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
  # 连通性检查（严格模式，所有节点必须可达）
  module::preflight_connectivity_strict "${ctx}" "$@" || return $?

  pipeline::upgrade_etcd "${ctx}" "$@"

  # 成功完成，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  logger::info "[Pipeline:upgrade_etcd] ETCD upgraded successfully!"
  return 0
}