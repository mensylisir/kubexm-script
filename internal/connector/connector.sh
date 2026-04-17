#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Connector (SSH Wrapper, New Architecture)
# ==============================================================================
# 职责: SSH 连接层封装，负责建立连接、命令下发及文件传输
# 设计原则: 严禁直接被 Step 调用，必须通过 Runner 调用
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# ==============================================================================
# SSH 连接参数获取
# ==============================================================================

# 一次性加载 ssh.sh（避免每次调用时重复 source）
source "${KUBEXM_ROOT}/internal/connector/ssh.sh"

# ==============================================================================
# localhost/127.0.0.1 校验
# ==============================================================================

# 校验 host 参数（禁止 localhost/127.0.0.1）
connector::_validate_host() {
  local host="$1"
  if [[ -z "${host}" || "${host}" == "localhost" || "${host}" == "127.0.0.1" ]]; then
    echo "connector: host is empty or localhost/127.0.0.1 forbidden" >&2
    return 2
  fi
  return 0
}

# ==============================================================================
# SSH 连接参数获取
# ==============================================================================

# 获取主机的 SSH 用户
connector::_get_ssh_user() {
  local host="$1"
  # 优先从 host.yaml 配置获取
  if type config::get_host_param &>/dev/null; then
    local user
    user=$(config::get_host_param "${host}" "user" 2>/dev/null || true)
    if [[ -n "${user}" ]]; then
      echo "${user}"
      return 0
    fi
  fi
  # 回退到默认用户
  if type defaults::get_ssh_user &>/dev/null; then
    defaults::get_ssh_user
  else
    echo "root"
  fi
}

# 获取主机的 SSH 密钥
connector::_get_ssh_key() {
  local host="$1"
  if type config::get_host_param &>/dev/null; then
    config::get_host_param "${host}" "ssh_key" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# 获取主机的 SSH 端口
connector::_get_ssh_port() {
  local host="$1"
  # 优先从 host.yaml 配置获取
  if type config::get_host_param &>/dev/null; then
    local port
    port=$(config::get_host_param "${host}" "ssh_port" 2>/dev/null || true)
    if [[ -n "${port}" ]]; then
      echo "${port}"
      return 0
    fi
  fi
  # 回退到默认端口
  if type defaults::get_ssh_port &>/dev/null; then
    defaults::get_ssh_port
  else
    echo "22"
  fi
}

# ==============================================================================
# SSH 执行（内部使用 ssh.sh）
# ==============================================================================

# 执行远程命令
# 用法: connector::exec <host> <cmd>
connector::exec() {
  local host="$1"
  local cmd="$2"

  connector::_validate_host "${host}" || return $?

  # 获取 SSH 参数
  local ssh_user
  ssh_user=$(connector::_get_ssh_user "${host}")
  local ssh_key
  ssh_key=$(connector::_get_ssh_key "${host}")
  local ssh_port
  ssh_port=$(connector::_get_ssh_port "${host}")

  # 使用预加载的 ssh.sh 执行
  ssh::execute "${host}" "${cmd}" "${ssh_user}" "${ssh_key}" "" "${ssh_port}"
}

# 复制文件到远程（上传）
# 用法: connector::copy_file <src> <host> <dest>
connector::copy_file() {
  local src="$1"
  local host="$2"
  local dest="$3"

  connector::_validate_host "${host}" || return $?

  # 获取 SSH 参数
  local ssh_user
  ssh_user=$(connector::_get_ssh_user "${host}")
  local ssh_key
  ssh_key=$(connector::_get_ssh_key "${host}")
  local ssh_port
  ssh_port=$(connector::_get_ssh_port "${host}")

  # 使用预加载的 ssh.sh 执行
  ssh::copy_file "${src}" "${host}" "${dest}" "${ssh_user}" "${ssh_key}" "" "${ssh_port}"
}

# 从远程复制文件（下载）
# 用法: connector::copy_from <host> <src> <dest>
connector::copy_from() {
  local host="$1"
  local src="$2"
  local dest="$3"

  connector::_validate_host "${host}" || return $?

  # 获取 SSH 参数
  local ssh_user
  ssh_user=$(connector::_get_ssh_user "${host}")
  local ssh_key
  ssh_key=$(connector::_get_ssh_key "${host}")
  local ssh_port
  ssh_port=$(connector::_get_ssh_port "${host}")

  # 使用预加载的 ssh.sh 执行
  ssh::copy_from "${host}" "${src}" "${dest}" "${ssh_user}" "${ssh_key}" "" "${ssh_port}"
}

# ==============================================================================
# 带重试的 SSH 执行
# ==============================================================================

# 执行远程命令（带指数退避重试）
# 用法: connector::exec_with_retry <host> <cmd> [max_attempts] [base_delay]
connector::exec_with_retry() {
  local host="$1"
  local cmd="$2"
  local max_attempts="${3:-3}"
  local base_delay="${4:-2}"

  connector::_validate_host "${host}" || return $?

  local ssh_user ssh_key ssh_port
  ssh_user=$(connector::_get_ssh_user "${host}")
  ssh_key=$(connector::_get_ssh_key "${host}")
  ssh_port=$(connector::_get_ssh_port "${host}")

  local attempt=1 delay
  while [[ ${attempt} -le ${max_attempts} ]]; do
    if ssh::execute "${host}" "${cmd}" "${ssh_user}" "${ssh_key}" "" "${ssh_port}"; then
      return 0
    fi
    if [[ ${attempt} -lt ${max_attempts} ]]; then
      delay=$(( base_delay * (1 << (attempt - 1)) ))
      [[ ${delay} -gt 30 ]] && delay=30
      sleep "${delay}"
    fi
    ((attempt++)) || true
  done
  return 1
}

# 复制文件到远程（带重试）
# 用法: connector::copy_file_with_retry <src> <host> <dest> [max_attempts] [base_delay]
connector::copy_file_with_retry() {
  local src="$1"
  local host="$2"
  local dest="$3"
  local max_attempts="${4:-3}"
  local base_delay="${5:-2}"

  connector::_validate_host "${host}" || return $?

  local ssh_user ssh_key ssh_port
  ssh_user=$(connector::_get_ssh_user "${host}")
  ssh_key=$(connector::_get_ssh_key "${host}")
  ssh_port=$(connector::_get_ssh_port "${host}")

  local attempt=1 delay
  while [[ ${attempt} -le ${max_attempts} ]]; do
    if ssh::copy_file "${src}" "${host}" "${dest}" "${ssh_user}" "${ssh_key}" "" "${ssh_port}"; then
      return 0
    fi
    if [[ ${attempt} -lt ${max_attempts} ]]; then
      delay=$(( base_delay * (1 << (attempt - 1)) ))
      [[ ${delay} -gt 30 ]] && delay=30
      sleep "${delay}"
    fi
    ((attempt++)) || true
  done
  return 1
}

# ==============================================================================
# 导出函数
# ==============================================================================

export -f connector::exec
export -f connector::copy_file
export -f connector::copy_from
export -f connector::exec_with_retry
export -f connector::copy_file_with_retry
