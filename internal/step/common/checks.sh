#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Step Idempotency Check Helpers
# ==============================================================================
# 提供通用的幂等性检查函数，供所有 Step 使用
# 设计原则：check 返回 0 表示"已满足"（跳过执行），返回 1 表示"未满足"（需要执行）
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# ==============================================================================
# 二进制文件检查
# ==============================================================================

#######################################
# 检查命令是否存在
# 用法: step::check::command_exists <command>
# 返回: 0 if exists, 1 if not
#######################################
step::check::command_exists() {
  local cmd="$1"
  if command -v "${cmd}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

#######################################
# 检查文件是否存在
# 用法: step::check::file_exists <file_path>
# 返回: 0 if exists, 1 if not
#######################################
step::check::file_exists() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    return 0
  fi
  return 1
}

#######################################
# 检查目录是否存在
# 用法: step::check::dir_exists <dir_path>
# 返回: 0 if exists, 1 if not
#######################################
step::check::dir_exists() {
  local dir="$1"
  if [[ -d "${dir}" ]]; then
    return 0
  fi
  return 1
}

#######################################
# 检查服务是否运行（systemd）
# 用法: step::check::service_running <service_name>
# 返回: 0 if running, 1 if not
#######################################
step::check::service_running() {
  local service="$1"
  if systemctl is-active --quiet "${service}" 2>/dev/null; then
    return 0
  fi
  return 1
}

#######################################
# 检查服务是否启用（systemd）
# 用法: step::check::service_enabled <service_name>
# 返回: 0 if enabled, 1 if not
#######################################
step::check::service_enabled() {
  local service="$1"
  if systemctl is-enabled --quiet "${service}" 2>/dev/null; then
    return 0
  fi
  return 1
}

#######################################
# 检查文件内容是否匹配
# 用法: step::check::file_matches <file_path> <pattern>
# 返回: 0 if matches, 1 if not
#######################################
step::check::file_matches() {
  local file="$1"
  local pattern="$2"
  if [[ -f "${file}" ]] && grep -q -- "${pattern}" "${file}" 2>/dev/null; then
    return 0
  fi
  return 1
}

#######################################
# 检查进程是否运行
# 用法: step::check::process_running <process_name>
# 返回: 0 if running, 1 if not
#######################################
step::check::process_running() {
  local process="$1"
  if pgrep -x "${process}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

#######################################
# 检查端口是否监听
# 用法: step::check::port_listening <port>
# 返回: 0 if listening, 1 if not
#######################################
step::check::port_listening() {
  local port="$1"
  if ss -tlnp 2>/dev/null | grep -q ":${port} " || netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
    return 0
  fi
  return 1
}

#######################################
# 检查版本匹配
# 用法: step::check::version_matches <actual_version> <expected_version>
# 返回: 0 if matches, 1 if not
#######################################
step::check::version_matches() {
  local actual="$1"
  local expected="$2"
  if [[ "${actual}" == "${expected}" ]]; then
    return 0
  fi
  return 1
}

#######################################
# 检查二进制的版本
# 用法: step::check::binary_version <binary> <version_arg> <expected_pattern>
# 示例: step::check::binary_version "containerd" "--version" "1.7"
# 返回: 0 if version matches pattern, 1 if not
#######################################
step::check::binary_version() {
  local binary="$1"
  local version_arg="$2"
  local expected_pattern="$3"

  if ! command -v "${binary}" >/dev/null 2>&1; then
    return 1
  fi

  local version
  version=$("${binary}" "${version_arg}" 2>/dev/null | head -1)
  if echo "${version}" | grep -q -- "${expected_pattern}"; then
    return 0
  fi
  return 1
}

#######################################
# 检查远程主机上的命令是否存在
# 用法: step::check::remote_command_exists <host> <command>
# 注意：必须通过 runner 调用以确保 KUBEXM_HOST 已设置
# 返回: 0 if exists, 1 if not
#######################################
step::check::remote_command_exists() {
  local host="$1"
  local cmd="$2"

  if [[ -z "${host}" ]]; then
    return 1
  fi

  local saved_host="${KUBEXM_HOST:-}"
  KUBEXM_HOST="${host}"
  local result
  if result=$(runner::remote_exec "command -v ${cmd}" 2>/dev/null); then
    KUBEXM_HOST="${saved_host}"
    return 0
  fi
  KUBEXM_HOST="${saved_host}"
  return 1
}

#######################################
# 检查远程主机上的文件是否存在
# 用法: step::check::remote_file_exists <host> <file_path>
# 返回: 0 if exists, 1 if not
#######################################
step::check::remote_file_exists() {
  local host="$1"
  local file="$2"

  if [[ -z "${host}" ]]; then
    return 1
  fi

  local saved_host="${KUBEXM_HOST:-}"
  KUBEXM_HOST="${host}"
  if runner::remote_exec "test -f ${file}" >/dev/null 2>&1; then
    KUBEXM_HOST="${saved_host}"
    return 0
  fi
  KUBEXM_HOST="${saved_host}"
  return 1
}

#######################################
# 检查远程主机上的服务是否运行
# 用法: step::check::remote_service_running <host> <service_name>
# 返回: 0 if running, 1 if not
#######################################
step::check::remote_service_running() {
  local host="$1"
  local service="$2"

  if [[ -z "${host}" ]]; then
    return 1
  fi

  local saved_host="${KUBEXM_HOST:-}"
  KUBEXM_HOST="${host}"
  if runner::remote_exec "systemctl is-active --quiet ${service}" >/dev/null 2>&1; then
    KUBEXM_HOST="${saved_host}"
    return 0
  fi
  KUBEXM_HOST="${saved_host}"
  return 1
}

#######################################
# 检查远程主机上的目录是否存在
# 用法: step::check::remote_dir_exists <host> <dir_path>
# 返回: 0 if exists, 1 if not
#######################################
step::check::remote_dir_exists() {
  local host="$1"
  local dir="$2"

  if [[ -z "${host}" ]]; then
    return 1
  fi

  local saved_host="${KUBEXM_HOST:-}"
  KUBEXM_HOST="${host}"
  if runner::remote_exec "test -d ${dir}" >/dev/null 2>&1; then
    KUBEXM_HOST="${saved_host}"
    return 0
  fi
  KUBEXM_HOST="${saved_host}"
  return 1
}

#######################################
# 检查远程主机是否可达（SSH）
# 用法: step::check::host_reachable [timeout_seconds]
# 注意：必须在 runner 上下文中使用（KUBEXM_HOST 已设置）
# 返回: 0 if reachable, 1 if not (skip step)
#######################################
step::check::host_reachable() {
  local timeout="${1:-5}"
  if ! timeout "${timeout}" runner::remote_exec "echo 'connection test'" >/dev/null 2>&1; then
    return 1  # 不可达，返回 1 以跳过此步骤
  fi
  return 0  # 可达
}

# ==============================================================================
# 导出所有函数
# ==============================================================================

export -f step::check::command_exists
export -f step::check::file_exists
export -f step::check::dir_exists
export -f step::check::service_running
export -f step::check::service_enabled
export -f step::check::file_matches
export -f step::check::process_running
export -f step::check::port_listening
export -f step::check::version_matches
export -f step::check::binary_version
export -f step::check::remote_command_exists
export -f step::check::remote_file_exists
export -f step::check::remote_service_running
export -f step::check::remote_dir_exists
