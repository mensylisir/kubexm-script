#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Step Runner (New Architecture)
# ==============================================================================
# 职责: 屏蔽执行细节，将 Step 转换为具体命令下发
# 设计原则: Step 严禁直接调用 Connector，必须通过 Runner 调用
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# ==============================================================================
# 主机标准化
# ==============================================================================

# 解析本地大网地址
runner::resolve_local_primary_ip() {
  local ip
  ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')
  if [[ -n "${ip}" ]]; then
    printf '%s' "${ip}"
    return 0
  fi
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -n "${ip}" ]]; then
    printf '%s' "${ip}"
    return 0
  fi
  return 1
}

# 标准化主机地址（禁止 localhost/127.0.0.1）
runner::normalize_host() {
  local host="$1"

  # 空值 → 使用本机大网地址
  if [[ -z "${host}" ]]; then
    local resolved
    resolved="$(runner::resolve_local_primary_ip || true)"
    if [[ -z "${resolved}" ]]; then
      echo "Failed to resolve local primary IP" >&2
      return 2
    fi
    printf '%s' "${resolved}"
    return 0
  fi

  # 禁止 localhost/127.0.0.1
  if [[ "${host}" == "localhost" || "${host}" == "127.0.0.1" ]]; then
    local resolved
    resolved="$(runner::resolve_local_primary_ip || true)"
    if [[ -z "${resolved}" ]]; then
      echo "localhost/127.0.0.1 forbidden, and failed to resolve local IP" >&2
      return 2
    fi
    printf '%s' "${resolved}"
    return 0
  fi

  # 正常地址直接返回
  printf '%s' "${host}"
}

# ==============================================================================
# Step 执行引擎
# ==============================================================================

# Rollback 追踪栈
declare -a RUNNER_ROLLBACK_STACK=()

# 记录需要回滚的步骤
runner::register_rollback() {
  local step_name="$1"
  RUNNER_ROLLBACK_STACK+=("${step_name}")
  
  # Also register with pipeline-level rollback if available
  if type pipeline::register_rollback &>/dev/null; then
    pipeline::register_rollback "Step rollback: ${step_name}" \
      "runner::execute_rollback 2>/dev/null || logger::warn 'Runner rollback failed for ${step_name}'"
  fi
}

# 清除回滚栈
runner::clear_rollback() {
  RUNNER_ROLLBACK_STACK=()
}

# 执行回滚（按逆序）
runner::execute_rollback() {
  if [[ ${#RUNNER_ROLLBACK_STACK[@]} -eq 0 ]]; then
    return 0
  fi

  log::warn "Executing rollback for ${#RUNNER_ROLLBACK_STACK[@]} step(s)..."

  local step
  local rollback_failed=0
  for ((i=${#RUNNER_ROLLBACK_STACK[@]}-1; i>=0; i--)); do
    step="${RUNNER_ROLLBACK_STACK[i]}"
    log::debug "Rolling back: ${step}"
    if "step::${step}::rollback" 2>/dev/null; then
      log::debug "Rollback success: ${step}"
    else
      log::error "Rollback failed: ${step}"
      rollback_failed=1
    fi
  done

  RUNNER_ROLLBACK_STACK=()

  if [[ "${rollback_failed}" -eq 1 ]]; then
    return 1
  fi
  return 0
}

# 执行单个 Step（check → run → check）
# 用法: runner::exec <step_name> <ctx> <host> [args...]
runner::exec() {
  local step_name="$1"
  local ctx="$2"
  local host="$3"
  shift 3
  local args=("$@")

  # 标准化主机（禁止 localhost/127.0.0.1）
  KUBEXM_HOST="$(runner::normalize_host "${host}")" || return 2

  # 设置 Step 名称
  KUBEXM_STEP_NAME="${step_name}"

  # DRY-RUN 模式
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    log::info "DRY-RUN step=${step_name} host=${KUBEXM_HOST}"
    return 0
  fi

  # 幂等性检查（check 返回 0 表示已满足，跳过 run）
  if "step::${step_name}::check" "${ctx}" "${args[@]}"; then
    log::debug "Step already satisfied, skipping: ${step_name} host=${KUBEXM_HOST}"
    return 0
  fi

  # 执行 Step
  if ! "step::${step_name}::run" "${ctx}" "${args[@]}"; then
    log::error "Step run failed: ${step_name} host=${KUBEXM_HOST}"
    # 执行回滚
    runner::execute_rollback
    return 1
  fi

  # 验证执行结果
  if ! "step::${step_name}::check" "${ctx}" "${args[@]}"; then
    log::error "Step check failed after run: ${step_name} host=${KUBEXM_HOST}"
    # 执行回滚
    runner::execute_rollback
    return 1
  fi

  # 注册此步骤到回滚栈（成功后）
  runner::register_rollback "${step_name}"

  log::debug "Step completed: ${step_name} host=${KUBEXM_HOST}"
  return 0
}

# ==============================================================================
# 远程执行
# ==============================================================================

# 远程执行命令
# 用法: runner::remote_exec <cmd>
runner::remote_exec() {
  local cmd="$1"
  : "${KUBEXM_HOST:?KUBEXM_HOST is required}"
  connector::exec "${KUBEXM_HOST}" "${cmd}"
}

# 远程复制文件（上传）
# 用法: runner::remote_copy_file <src> <dest>
runner::remote_copy_file() {
  local src="$1"
  local dest="$2"
  : "${KUBEXM_HOST:?KUBEXM_HOST is required}"
  connector::copy_file "${src}" "${KUBEXM_HOST}" "${dest}"
}

# 远程复制文件（下载）
# 用法: runner::remote_copy_from <src> <dest>
runner::remote_copy_from() {
  local src="$1"
  local dest="$2"
  : "${KUBEXM_HOST:?KUBEXM_HOST is required}"
  connector::copy_from "${KUBEXM_HOST}" "${src}" "${dest}"
}

# ==============================================================================
# 语义化服务操作（封装 systemctl 命令）
# ==============================================================================

# ==============================================================================
# 导出函数
# ==============================================================================

export -f runner::resolve_local_primary_ip
export -f runner::normalize_host
export -f runner::register_rollback
export -f runner::clear_rollback
export -f runner::execute_rollback
export -f runner::exec
export -f runner::remote_exec
export -f runner::remote_copy_file
export -f runner::remote_copy_from
