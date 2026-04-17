#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Pipeline Utilities
# ==============================================================================
# 为 pipeline 层提供：超时控制、回滚栈、进度报告
# ==============================================================================

source "${KUBEXM_ROOT}/internal/logger/log.sh"

# ==============================================================================
# 超时控制
# ==============================================================================

# 默认超时（秒）
KUBEXM_PIPELINE_TIMEOUT="${KUBEXM_PIPELINE_TIMEOUT:-3600}"  # 1小时

pipeline::_timeout_handler() {
  log::error "Pipeline '${KUBEXM_PIPELINE_NAME:-unknown}' exceeded timeout of ${KUBEXM_PIPELINE_TIMEOUT}s"
  # 触发回滚
  if type pipeline::_rollback_all &>/dev/null; then
    pipeline::_rollback_all
  fi
  exit 6  # ERR_TIMEOUT
}

# 启动超时监控（后台 watchdog）
pipeline::start_timeout_watchdog() {
  local timeout="${KUBEXM_PIPELINE_TIMEOUT}"
  local pipeline_name="${KUBEXM_PIPELINE_NAME:-unknown}"

  (
    sleep "${timeout}"
    log::error "Pipeline '${pipeline_name}' exceeded timeout of ${timeout}s, terminating..."
    # 发送 TERM 给当前脚本的父进程
    kill -TERM $$ 2>/dev/null || true
  ) &
  # 保存 watchdog PID 用于清理
  KUBEXM_TIMEOUT_WATCHDOG_PID=$!
  export KUBEXM_TIMEOUT_WATCHDOG_PID
}

# 停止超时监控
pipeline::stop_timeout_watchdog() {
  if [[ -n "${KUBEXM_TIMEOUT_WATCHDOG_PID:-}" ]]; then
    kill "${KUBEXM_TIMEOUT_WATCHDOG_PID}" 2>/dev/null || true
    wait "${KUBEXM_TIMEOUT_WATCHDOG_PID}" 2>/dev/null || true
    unset KUBEXM_TIMEOUT_WATCHDOG_PID
  fi
}

# ==============================================================================
# 回滚栈
# ==============================================================================

declare -a KUBEXM_PIPELINE_ROLLBACK_STACK=()
declare -a KUBEXM_PIPELINE_ROLLBACK_DESC=()

# 注册回滚动作
# 用法: pipeline::register_rollback "描述" "回滚函数" [参数...]
pipeline::register_rollback() {
  local desc="$1"
  shift
  KUBEXM_PIPELINE_ROLLBACK_STACK+=("$*")
  KUBEXM_PIPELINE_ROLLBACK_DESC+=("${desc}")
  log::debug "Rollback registered: ${desc}"
}

# 执行所有回滚（逆序）
pipeline::_rollback_all() {
  local count=${#KUBEXM_PIPELINE_ROLLBACK_STACK[@]}
  if [[ ${count} -eq 0 ]]; then
    log::info "No rollback actions registered"
    return 0
  fi

  log::warn "Rolling back ${count} action(s) in reverse order..."
  for ((i=count-1; i>=0; i--)); do
    local desc="${KUBEXM_PIPELINE_ROLLBACK_DESC[i]}"
    local cmd="${KUBEXM_PIPELINE_ROLLBACK_STACK[i]}"
    log::info "Rollback [${i}]: ${desc}"
    if ! eval "${cmd}" 2>/dev/null; then
      log::warn "Rollback [${i}] failed: ${desc} (continuing...)"
    fi
  done
  log::warn "Rollback completed"
  KUBEXM_PIPELINE_ROLLBACK_STACK=()
  KUBEXM_PIPELINE_ROLLBACK_DESC=()
}

# 清空回滚栈（成功完成后调用）
pipeline::clear_rollback_stack() {
  KUBEXM_PIPELINE_ROLLBACK_STACK=()
  KUBEXM_PIPELINE_ROLLBACK_DESC=()
}

# 注册模块级回滚动作 (helper for common patterns)
# 用法: pipeline::register_module_rollback "module_name" "action"
# 支持的动作: install, upgrade, configure
pipeline::register_module_rollback() {
  local module="$1"
  local action="$2"
  local ctx="${3:-}"

  case "${action}" in
    install)
      pipeline::register_rollback \
        "Uninstall ${module}" \
        "module::${module}_delete '${ctx}' 2>/dev/null || logger::warn 'Rollback warning: failed to uninstall ${module}'"
      ;;
    upgrade)
      # Upgrade rollback requires version tracking - placeholder for future enhancement
      pipeline::register_rollback \
        "Mark ${module} upgrade for manual rollback if needed" \
        "logger::warn 'Manual rollback may be required for ${module} upgrade'"
      ;;
    configure)
      pipeline::register_rollback \
        "Revert ${module} configuration" \
        "logger::warn 'Configuration rollback for ${module} may require manual intervention'"
      ;;
    *)
      log::warn "Unknown rollback action: ${action} for module: ${module}"
      ;;
  esac
}

# 创建操作前备份
# 用法: pipeline::ensure_pre_operation_backup "operation_name"
# Returns: 0 成功, 1 失败 (当强制备份时)
pipeline::ensure_pre_operation_backup() {
  local operation="$1"
  local force_backup="${2:-true}"  # 默认强制备份
  local backup_dir="/tmp/kubexm-backups/${KUBEXM_CLUSTER_NAME}"
  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)
  local backup_path="${backup_dir}/pre-${operation}-${timestamp}.db"

  mkdir -p "${backup_dir}"

  logger::info "Creating pre-${operation} backup..."
  logger::info "Backup path: ${backup_path}"

  # Try to create etcd snapshot
  if command -v etcdctl &>/dev/null; then
    if ETCDCTL_API=3 etcdctl snapshot save "${backup_path}" \
      --endpoints="https://127.0.0.1:2379" \
      --cacert="/etc/kubernetes/pki/etcd/ca.crt" \
      --cert="/etc/kubernetes/pki/etcd/healthcheck-client.crt" \
      --key="/etc/kubernetes/pki/etcd/healthcheck-client.key" \
      2>/dev/null; then
      
      logger::info "Pre-${operation} backup created successfully: ${backup_path}"
      export KUBEXM_PRE_OPERATION_BACKUP="${backup_path}"
      return 0
    else
      logger::warn "Failed to create etcd snapshot backup"
      if [[ "${force_backup}" == "true" ]]; then
        logger::error "Pre-operation backup is REQUIRED but failed! Aborting for safety."
        return 1
      fi
      logger::warn "Continuing without backup (NOT RECOMMENDED)"
      return 0
    fi
  else
    logger::warn "etcdctl not found, skipping backup"
    if [[ "${force_backup}" == "true" ]]; then
      logger::error "etcdctl required for backup but not found! Aborting."
      return 1
    fi
    return 0
  fi
}

export -f pipeline::register_module_rollback
export -f pipeline::ensure_pre_operation_backup

# ==============================================================================
# Quorum Validation
# ==============================================================================

# 验证删除节点后是否满足法定人数要求
# 用法: pipeline::validate_quorum_before_removal "role" "nodes_to_remove_count"
# Returns: 0 安全, 1 会破坏法定人数
pipeline::validate_quorum_before_removal() {
  local role="$1"
  local nodes_to_remove="${2:-1}"

  local current_count desired_count min_quorum

  case "${role}" in
    etcd)
      # Count current etcd members
      if command -v etcdctl &>/dev/null; then
        current_count=$(ETCDCTL_API=3 etcdctl member list \
          --endpoints="https://127.0.0.1:2379" \
          --cacert="/etc/kubernetes/pki/etcd/ca.crt" \
          --cert="/etc/kubernetes/pki/etcd/healthcheck-client.crt" \
          --key="/etc/kubernetes/pki/etcd/healthcheck-client.key" \
          2>/dev/null | wc -l || echo "0")
      else
        logger::warn "etcdctl not found, skipping quorum check"
        return 0
      fi

      if [[ ${current_count} -eq 0 ]]; then
        logger::warn "Cannot determine ETCD member count, skipping quorum check"
        return 0
      fi

      min_quorum=$(( (current_count / 2) + 1 ))
      desired_count=$(( current_count - nodes_to_remove ))

      logger::info "ETCD quorum check: current=${current_count}, removing=${nodes_to_remove}, after=${desired_count}, min_quorum=${min_quorum}"

      # Warn if resulting cluster size is even (suboptimal for fault tolerance)
      if [[ $((desired_count % 2)) -eq 0 ]]; then
        logger::warn "⚠️  WARNING: ETCD cluster will have ${desired_count} members (even number)"
        logger::warn "   Even-sized clusters have the same fault tolerance as odd-sized clusters with one fewer member"
        logger::warn "   Recommended: Keep ETCD cluster size odd (1, 3, 5, 7...) for optimal fault tolerance"
        logger::warn "   Current fault tolerance: can tolerate $(( (desired_count / 2) - 1 )) failures"
      fi

      if [[ ${desired_count} -lt ${min_quorum} ]]; then
        logger::error "═══════════════════════════════════════════════════════"
        logger::error "QUORUM VIOLATION DETECTED!"
        logger::error "═══════════════════════════════════════════════════════"
        logger::error "Removing ${nodes_to_remove} ETCD node(s) would break quorum!"
        logger::error ""
        logger::error "Current ETCD members:  ${current_count}"
        logger::error "After removal:          ${desired_count}"
        logger::error "Minimum quorum required: ${min_quorum}"
        logger::error ""
        logger::error "This operation will make the cluster UNUSABLE!"
        logger::error "Please add more ETCD nodes before removing existing ones."
        logger::error "═══════════════════════════════════════════════════════"
        return 1
      fi

      logger::info "Quorum check PASSED: ${desired_count} >= ${min_quorum}"
      ;;

    control-plane|master)
      # For control-plane, we check via kubectl
      if command -v kubectl &>/dev/null; then
        current_count=$(kubectl get nodes \
          --selector='node-role.kubernetes.io/control-plane' \
          -o json 2>/dev/null | jq '.items | length' || echo "0")
      else
        logger::warn "kubectl not found, skipping control-plane quorum check"
        return 0
      fi

      if [[ ${current_count} -eq 0 ]]; then
        logger::warn "Cannot determine control-plane node count, skipping quorum check"
        return 0
      fi

      # For HA, we need at least 1 control-plane node remaining
      # For production, recommend at least 3
      min_quorum=1
      desired_count=$(( current_count - nodes_to_remove ))

      logger::info "Control-plane check: current=${current_count}, removing=${nodes_to_remove}, after=${desired_count}, minimum=${min_quorum}"

      if [[ ${desired_count} -lt ${min_quorum} ]]; then
        logger::error "═══════════════════════════════════════════════════════"
        logger::error "CONTROL-PLANE VIOLATION DETECTED!"
        logger::error "═══════════════════════════════════════════════════════"
        logger::error "Removing ${nodes_to_remove} control-plane node(s) would leave cluster without control plane!"
        logger::error ""
        logger::error "Current control-plane nodes: ${current_count}"
        logger::error "After removal:               ${desired_count}"
        logger::error "Minimum required:             ${min_quorum}"
        logger::error ""
        logger::error "This operation will DESTROY the cluster!"
        logger::error "═══════════════════════════════════════════════════════"
        return 1
      fi

      # Warning for non-HA setups
      if [[ ${desired_count} -eq 1 ]]; then
        logger::warn "⚠️  WARNING: Cluster will have only 1 control-plane node after removal"
        logger::warn "   This is NOT recommended for production (no HA)"
        logger::warn "   Consider keeping at least 3 control-plane nodes"
      fi

      logger::info "Control-plane check PASSED"
      ;;

    worker)
      # Workers don't have quorum requirements, but warn about capacity
      logger::info "Worker nodes have no quorum requirements (safe to remove)"
      ;;

    *)
      logger::warn "Unknown role for quorum check: ${role}"
      ;;
  esac

  return 0
}

export -f pipeline::validate_quorum_before_removal

# ==============================================================================
# 进度报告
# ==============================================================================

declare -i KUBEXM_PIPELINE_STEP_TOTAL=0
declare -i KUBEXM_PIPELINE_STEP_CURRENT=0
declare -i KUBEXM_PIPELINE_STEP_SKIPPED=0
declare -i KUBEXM_PIPELINE_STEP_FAILED=0

pipeline::init_progress() {
  local total="$1"
  KUBEXM_PIPELINE_STEP_TOTAL=${total}
  KUBEXM_PIPELINE_STEP_CURRENT=0
  KUBEXM_PIPELINE_STEP_SKIPPED=0
  KUBEXM_PIPELINE_STEP_FAILED=0
}

pipeline::step_start() {
  local name="$1"
  ((KUBEXM_PIPELINE_STEP_CURRENT++)) || true
  local pct=0
  if [[ ${KUBEXM_PIPELINE_STEP_TOTAL} -gt 0 ]]; then
    pct=$(( (KUBEXM_PIPELINE_STEP_CURRENT - 1) * 100 / KUBEXM_PIPELINE_STEP_TOTAL ))
  fi
  log::info "[${pct}%] Starting: ${name}"
}

pipeline::step_complete() {
  local name="$1"
  local pct=0
  if [[ ${KUBEXM_PIPELINE_STEP_TOTAL} -gt 0 ]]; then
    pct=$(( KUBEXM_PIPELINE_STEP_CURRENT * 100 / KUBEXM_PIPELINE_STEP_TOTAL ))
  fi
  log::info "[${pct}%] Completed: ${name}"
}

pipeline::step_skip() {
  local name="$1"
  ((KUBEXM_PIPELINE_STEP_SKIPPED++)) || true
  log::info "[SKIP] ${name}"
}

pipeline::step_fail() {
  local name="$1"
  ((KUBEXM_PIPELINE_STEP_FAILED++)) || true
  log::error "[FAIL] ${name}"
}

pipeline::summary() {
  local total=${KUBEXM_PIPELINE_STEP_TOTAL}
  local current=${KUBEXM_PIPELINE_STEP_CURRENT}
  local skipped=${KUBEXM_PIPELINE_STEP_SKIPPED}
  local failed=${KUBEXM_PIPELINE_STEP_FAILED}
  log::info "Pipeline summary: ${current}/${total} steps, ${skipped} skipped, ${failed} failed"
}

export -f pipeline::start_timeout_watchdog
export -f pipeline::stop_timeout_watchdog
export -f pipeline::register_rollback
export -f pipeline::_rollback_all
export -f pipeline::clear_rollback_stack
export -f pipeline::init_progress
export -f pipeline::step_start
export -f pipeline::step_complete
export -f pipeline::step_skip
export -f pipeline::step_fail
export -f pipeline::summary

# ==============================================================================
# 并发锁（flock 基于文件）
# ==============================================================================

KUBEXM_LOCK_DIR="${KUBEXM_LOCK_DIR:-/tmp/kubexm-locks}"

# 获取集群锁
# 用法: pipeline::acquire_lock "cluster-name" [timeout_seconds]
# Returns: 0 成功, 1 超时
pipeline::acquire_lock() {
  local cluster_name="$1"
  local timeout="${2:-300}"  # 默认等待 5 分钟
  local lock_file="${KUBEXM_LOCK_DIR}/${cluster_name}.lock"

  mkdir -p "${KUBEXM_LOCK_DIR}"

  # 创建 lock file descriptor 9
  eval "exec 9>\"${lock_file}\""

  log::info "Acquiring lock for cluster '${cluster_name}' (timeout: ${timeout}s)..."
  if ! flock -w "${timeout}" 9; then
    log::error "Failed to acquire lock for cluster '${cluster_name}' after ${timeout}s. Another pipeline may be running."
    return 1
  fi

  # 写入锁持有者信息
  echo "$$ ${KUBEXM_PIPELINE_NAME:-unknown} $(date +%s)" >&9
  log::info "Lock acquired for cluster '${cluster_name}'"
  return 0
}

# 释放集群锁
pipeline::release_lock() {
  local cluster_name="$1"
  log::info "Releasing lock for cluster '${cluster_name}'"
  flock -u 9 2>/dev/null || true
  eval "exec 9>&-" 2>/dev/null || true
}
