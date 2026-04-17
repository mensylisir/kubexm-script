#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - SSH Operations
# ==============================================================================
# 提供SSH远程操作功能
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# ==============================================================================
# SSH操作
# ==============================================================================

#######################################
# 验证SSH密钥文件
# Arguments:
#   $1 - SSH密钥路径
# Returns:
#   0 valid, 1 invalid
#######################################
ssh::validate_key() {
  local ssh_key="$1"

  if [[ ! -f "${ssh_key}" ]]; then
    log::error "SSH private key not found: ${ssh_key}"
    return 1
  fi

  local perms
  perms=$(stat -c '%a' "${ssh_key}" 2>/dev/null || stat -f '%Lp' "${ssh_key}" 2>/dev/null || echo "")
  if [[ "${perms}" != "600" && "${perms}" != "400" ]]; then
    log::warn "SSH private key ${ssh_key} has permissions ${perms} (expected 600 or 400). Fixing..."
    chmod 600 "${ssh_key}" 2>/dev/null || {
      log::error "Failed to fix SSH key permissions: ${ssh_key}"
      return 1
    }
    log::info "SSH key permissions corrected to 600"
  fi

  return 0
}

#######################################
# 测试SSH连接
# Arguments:
#   $1 - 节点IP
#   $2 - SSH用户
#   $3 - SSH密钥（可选）
#   $4 - SSH端口（可选，默认22）
# Returns:
#   0 on success, 1 on failure
#######################################
ssh::test_connectivity() {
  local node_ip="$1"
  local ssh_user="${2:-$(defaults::get_ssh_user)}"
  local ssh_key="${3:-}"
  local ssh_port="${4:-22}"

  if [[ -n "${ssh_key}" ]]; then
    ssh::validate_key "${ssh_key}" || return 1
  fi

  local ssh_cmd="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5"
  if [[ -n "${ssh_key}" ]]; then
    ssh_cmd+=" -i $(printf '%q' "${ssh_key}")"
  fi
  if [[ "${ssh_port}" != "22" ]]; then
    ssh_cmd+=" -p ${ssh_port}"
  fi
  ssh_cmd+=" ${ssh_user}@${node_ip} 'echo connected'"

  if eval "${ssh_cmd}" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

#######################################
# 在远程节点执行命令
# Arguments:
#   $1 - 节点IP
#   $2 - 要执行的命令
#   $3 - SSH用户
#   $4 - SSH密钥（可选）
#   $5 - SSH密码（可选）
#   $6 - SSH端口（可选，默认22）
# Returns:
#   命令输出
#######################################
ssh::execute() {
  local node_ip="$1"
  local command="$2"
  local ssh_user="${3:-$(defaults::get_ssh_user)}"
  local ssh_key="${4:-}"
  local ssh_password="${5:-}"
  local ssh_port="${6:-22}"

  local ssh_cmd="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30"
  if [[ -n "${ssh_key}" ]]; then
    ssh::validate_key "${ssh_key}" || return 1
    ssh_cmd+=" -i $(printf '%q' "${ssh_key}")"
  elif [[ -n "${ssh_password}" ]]; then
    ssh_cmd+=" -o PasswordAuthentication=yes"
  fi
  if [[ "${ssh_port}" != "22" ]]; then
    ssh_cmd+=" -p ${ssh_port}"
  fi
  ssh_cmd+=" ${ssh_user}@${node_ip} $(printf '%q' "${command}")"

  eval "${ssh_cmd}"
}

#######################################
# 复制文件到远程节点
# Arguments:
#   $1 - 本地文件路径
#   $2 - 节点IP
#   $3 - 远程文件路径
#   $4 - SSH用户
#   $5 - SSH密钥（可选）
#   $6 - SSH密码（可选）
#   $7 - SSH端口（可选，默认22）
# Returns:
#   0 on success, 1 on failure
#######################################
ssh::copy_file() {
  local local_file="$1"
  local node_ip="$2"
  local remote_file="$3"
  local ssh_user="${4:-$(defaults::get_ssh_user)}"
  local ssh_key="${5:-}"
  local ssh_password="${6:-}"
  local ssh_port="${7:-22}"

  local scp_cmd="scp -o StrictHostKeyChecking=no -o ConnectTimeout=30"
  if [[ -n "${ssh_key}" ]]; then
    ssh::validate_key "${ssh_key}" || return 1
    scp_cmd+=" -i $(printf '%q' "${ssh_key}")"
  elif [[ -n "${ssh_password}" ]]; then
    scp_cmd+=" -o PasswordAuthentication=yes"
  fi
  if [[ "${ssh_port}" != "22" ]]; then
    scp_cmd+=" -P ${ssh_port}"
  fi
  scp_cmd+=" ${local_file} ${ssh_user}@${node_ip}:${remote_file}"

  if eval "${scp_cmd}" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

#######################################
# 从远程节点复制文件
# Arguments:
#   $1 - 节点IP
#   $2 - 远程文件路径
#   $3 - 本地文件路径
#   $4 - SSH用户
#   $5 - SSH密钥（可选）
#   $6 - SSH密码（可选）
#   $7 - SSH端口（可选，默认22）
# Returns:
#   0 on success, 1 on failure
#######################################
ssh::copy_from() {
  local node_ip="$1"
  local remote_file="$2"
  local local_file="$3"
  local ssh_user="${4:-$(defaults::get_ssh_user)}"
  local ssh_key="${5:-}"
  local ssh_password="${6:-}"
  local ssh_port="${7:-22}"

  local scp_cmd="scp -o StrictHostKeyChecking=no -o ConnectTimeout=30"
  if [[ -n "${ssh_key}" ]]; then
    ssh::validate_key "${ssh_key}" || return 1
    scp_cmd+=" -i $(printf '%q' "${ssh_key}")"
  elif [[ -n "${ssh_password}" ]]; then
    scp_cmd+=" -o PasswordAuthentication=yes"
  fi
  if [[ "${ssh_port}" != "22" ]]; then
    scp_cmd+=" -P ${ssh_port}"
  fi
  scp_cmd+=" ${ssh_user}@${node_ip}:${remote_file} ${local_file}"

  if eval "${scp_cmd}" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

#######################################
# 带重试的远程命令执行
# Arguments:
#   $1 - 节点IP
#   $2 - 要执行的命令
#   $3 - SSH用户
#   $4 - SSH密钥（可选）
#   $5 - SSH密码（可选）
#   $6 - 最大重试次数（默认3）
#   $7 - 重试间隔秒数（默认2）
#   $8 - SSH端口（可选，默认22）
# Returns:
#   命令输出
#######################################
ssh::execute_with_retry() {
  local node_ip="$1"
  local command="$2"
  local ssh_user="${3:-$(defaults::get_ssh_user)}"
  local ssh_key="${4:-}"
  local ssh_password="${5:-}"
  local max_retries="${6:-3}"
  local retry_delay="${7:-2}"
  local ssh_port="${8:-22}"

  local attempt=1
  local result=""

  while [[ ${attempt} -le ${max_retries} ]]; do
    if result=$(ssh::execute "${node_ip}" "${command}" "${ssh_user}" "${ssh_key}" "${ssh_password}" "${ssh_port}" 2>&1); then
      echo "${result}"
      return 0
    fi

    if [[ ${attempt} -lt ${max_retries} ]]; then
      log::warn "SSH execute failed on ${node_ip}, retry ${attempt}/${max_retries} in ${retry_delay}s..."
      sleep "${retry_delay}"
      # 指数退避
      retry_delay=$((retry_delay * 2))
    fi
    ((attempt++)) || true
  done

  log::error "SSH execute failed on ${node_ip} after ${max_retries} attempts"
  return 1
}

#######################################
# 带重试的文件复制
# Arguments:
#   $1 - 本地文件路径
#   $2 - 节点IP
#   $3 - 远程文件路径
#   $4 - SSH用户
#   $5 - SSH密钥（可选）
#   $6 - SSH密码（可选）
#   $7 - 最大重试次数（默认3）
#   $8 - 重试间隔秒数（默认2）
#   $9 - SSH端口（可选，默认22）
# Returns:
#   0 on success, 1 on failure
#######################################
ssh::copy_file_with_retry() {
  local local_file="$1"
  local node_ip="$2"
  local remote_file="$3"
  local ssh_user="${4:-$(defaults::get_ssh_user)}"
  local ssh_key="${5:-}"
  local ssh_password="${6:-}"
  local max_retries="${7:-3}"
  local retry_delay="${8:-2}"
  local ssh_port="${9:-22}"

  local attempt=1

  while [[ ${attempt} -le ${max_retries} ]]; do
    if ssh::copy_file "${local_file}" "${node_ip}" "${remote_file}" "${ssh_user}" "${ssh_key}" "${ssh_password}" "${ssh_port}"; then
      return 0
    fi

    if [[ ${attempt} -lt ${max_retries} ]]; then
      log::warn "SCP copy failed to ${node_ip}, retry ${attempt}/${max_retries} in ${retry_delay}s..."
      sleep "${retry_delay}"
      retry_delay=$((retry_delay * 2))
    fi
    ((attempt++)) || true
  done

  log::error "SCP copy failed to ${node_ip} after ${max_retries} attempts"
  return 1
}

# 导出函数
export -f ssh::test_connectivity
export -f ssh::execute
export -f ssh::copy_file
export -f ssh::copy_from
export -f ssh::execute_with_retry
export -f ssh::copy_file_with_retry

#######################################
# 复制文件到远程节点（别名，向后兼容）
# 注意：参数顺序与 ssh::copy_file 不同
# Arguments:
#   $1 - 节点IP
#   $2 - 本地文件路径
#   $3 - 远程文件路径
#   $4 - SSH用户（可选）
#   $5 - SSH密钥（可选）
#   $6 - SSH密码（可选）
#   $7 - SSH端口（可选，默认22）
# Returns:
#   0 on success, 1 on failure
#######################################
ssh::scp_to() {
  local node_ip="$1"
  local local_file="$2"
  local remote_file="$3"
  local ssh_user="${4:-$(defaults::get_ssh_user)}"
  local ssh_key="${5:-}"
  local ssh_password="${6:-}"
  local ssh_port="${7:-22}"

  # 调用 ssh::copy_file（参数顺序不同）
  ssh::copy_file "${local_file}" "${node_ip}" "${remote_file}" "${ssh_user}" "${ssh_key}" "${ssh_password}" "${ssh_port}"
}
export -f ssh::scp_to

#######################################
# 执行远程命令（简化版别名，向后兼容）
# 用于 loadbalancer 和 rollback 脚本
# Arguments:
#   $1 - 节点名称或IP
#   $2 - 要执行的命令
#   $3 - SSH端口（可选，默认22）
# Returns:
#   命令输出
#######################################
ssh::exec() {
  local node="$1"
  local command="$2"
  local ssh_port="${3:-22}"

  # 如果node是hostname，尝试获取其IP
  local node_ip
  if type config::get_host_param &>/dev/null && config::get_host_param "${node}" "address" &>/dev/null 2>&1; then
    node_ip=$(config::get_host_param "${node}" "address")
  else
    node_ip="${node}"
  fi

  local ssh_user
  ssh_user=$(defaults::get_ssh_user 2>/dev/null || echo "root")

  ssh::execute "${node_ip}" "${command}" "${ssh_user}" "" "" "${ssh_port}"
}
export -f ssh::exec
