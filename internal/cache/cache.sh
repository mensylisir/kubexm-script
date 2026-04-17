#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Cache Manager
# ==============================================================================
# 缓存管理工具库
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 加载依赖
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/common.sh"

# 缓存目录
CACHE_DIR="${KUBEXM_CACHE_DIR:-${KUBEXM_SCRIPT_ROOT}/cache}"

#######################################
# 初始化缓存目录
# Arguments:
#   无
# Returns:
#   0 成功, 1 失败
#######################################
cache::init() {
  log::debug "Initializing cache directory: $CACHE_DIR"
  utils::ensure_dir "$CACHE_DIR"
}

#######################################
# 清理缓存
# Arguments:
#   $1 - 缓存键（可选，为空则清理所有）
# Returns:
#   0 成功, 1 失败
#######################################
cache::clean() {
  local key="$1"

  if [[ -z "$key" ]]; then
    log::info "Cleaning all cache..."
    rm -rf "$CACHE_DIR"/* 2>/dev/null || true
  else
    log::debug "Cleaning cache key: $key"
    rm -rf "$CACHE_DIR/$key" 2>/dev/null || true
  fi

  log::success "Cache cleaned"
  return 0
}

#######################################
# 设置缓存值
# Arguments:
#   $1 - 缓存键
#   $2 - 缓存值
#   $3 - TTL秒数（可选，默认3600）
# Returns:
#   0 成功, 1 失败
#######################################
cache::set() {
  local key="$1"
  local value="$2"
  local ttl="${3:-3600}"

  local cache_file="$CACHE_DIR/$key"
  utils::ensure_dir "$(dirname "$cache_file")"

  {
    echo "VALUE=$value"
    echo "TIMESTAMP=$(date +%s)"
    echo "TTL=$ttl"
  } > "$cache_file"

  log::debug "Cache set: $key (TTL: ${ttl}s)"
  return 0
}

#######################################
# 获取缓存值
# Arguments:
#   $1 - 缓存键
# Returns:
#   0 成功, 1 失败或已过期
# Outputs:
#   缓存值到stdout
#######################################
cache::get() {
  local key="$1"

  local cache_file="$CACHE_DIR/$key"
  if [[ ! -f "$cache_file" ]]; then
    log::debug "Cache miss: $key"
    return 1
  fi

  # 读取缓存文件
  local value
  local timestamp
  local ttl

  source "$cache_file"

  local current_time
  current_time=$(date +%s)
  local expire_time=$((timestamp + ttl))

  if [[ $current_time -gt $expire_time ]]; then
    log::debug "Cache expired: $key"
    rm -f "$cache_file"
    return 1
  fi

  echo "$value"
  log::debug "Cache hit: $key"
  return 0
}

#######################################
# 检查缓存是否存在且有效
# Arguments:
#   $1 - 缓存键
# Returns:
#   0 存在且有效, 1 不存在或已过期
#######################################
cache::exists() {
  local key="$1"

  local cache_file="$CACHE_DIR/$key"
  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  # 检查是否过期
  source "$cache_file"

  local current_time
  current_time=$(date +%s)
  local expire_time=$((timestamp + ttl))

  if [[ $current_time -gt $expire_time ]]; then
    log::debug "Cache expired: $key"
    rm -f "$cache_file"
    return 1
  fi

  return 0
}

#######################################
# 设置缓存（如果不存在则执行函数）
# Arguments:
#   $1 - 缓存键
#   $2 - TTL秒数
#   $3 - 要执行的函数名
#   $4... - 函数参数
# Returns:
#   0 成功, 1 失败
# Outputs:
#   函数输出到stdout
#######################################
cache::get_or_set() {
  local key="$1"
  local ttl="$2"
  local func="$3"
  shift 3

  # 尝试从缓存获取
  if cache::get "$key" 2>/dev/null; then
    return 0
  fi

  # 执行函数并缓存结果
  log::debug "Cache miss, executing: $func"
  local result
  result=$("$func" "$@")

  if [[ $? -eq 0 && -n "$result" ]]; then
    cache::set "$key" "$result" "$ttl"
    echo "$result"
    return 0
  else
    return 1
  fi
}

#######################################
# 缓存网络请求
# Arguments:
#   $1 - 缓存键
#   $2 - URL
#   $3 - TTL秒数（默认3600）
# Returns:
#   0 成功, 1 失败
# Outputs:
#   请求结果到stdout
#######################################
cache::http_get() {
  local key="$1"
  local url="$2"
  local ttl="${3:-3600}"

  cache::get_or_set "$key" "$ttl" utils::download_file "$url" - || return 1
}

#######################################
# 缓存命令输出
# Arguments:
#   $1 - 缓存键
#   $2 - TTL秒数
#   $3... - 要执行的命令
# Returns:
#   0 成功, 1 失败
# Outputs:
#   命令输出到stdout
#######################################
cache::command_output() {
  local key="$1"
  local ttl="$2"
  shift 2

  cache::get_or_set "$key" "$ttl" "$@" || return 1
}

#######################################
# 缓存文件内容
# Arguments:
#   $1 - 缓存键
#   $2 - 文件路径
#   $3 - TTL秒数（默认3600）
# Returns:
#   0 成功, 1 失败
# Outputs:
#   文件内容到stdout
#######################################
cache::file_content() {
  local key="$1"
  local file="$2"
  local ttl="${3:-3600}"

  local cache_key="file:${key}:${file}"
  cache::get_or_set "$cache_key" "$ttl" cat "$file" || return 1
}

#######################################
# 列出缓存键
# Arguments:
#   $1 - 前缀（可选）
# Returns:
#   0 成功, 1 失败
# Outputs:
#   缓存键列表到stdout
#######################################
cache::list_keys() {
  local prefix="$1"

  if [[ -z "$prefix" ]]; then
    find "$CACHE_DIR" -type f -printf '%P\n' 2>/dev/null | sort
  else
    find "$CACHE_DIR" -type f -path "*/${prefix}/*" -printf '%P\n' 2>/dev/null | sort
  fi
}

#######################################
# 获取缓存统计信息
# Arguments:
#   无
# Returns:
#   0 成功, 1 失败
# Outputs:
#   统计信息到stdout
#######################################
cache::stats() {
  local total_keys
  total_keys=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l)

  local total_size
  total_size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)

  echo "Cache Directory: $CACHE_DIR"
  echo "Total Keys: $total_keys"
  echo "Total Size: $total_size"
}

# 导出函数
export -f cache::init
export -f cache::clean
export -f cache::set
export -f cache::get
export -f cache::exists
export -f cache::get_or_set
export -f cache::http_get
export -f cache::command_output
export -f cache::file_content
export -f cache::list_keys
export -f cache::stats

# 初始化缓存
cache::init
