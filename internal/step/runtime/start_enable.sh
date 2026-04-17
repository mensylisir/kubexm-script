#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: runtime_start_enable
# 启动容器运行时并设置开机自启
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

step::runtime.start.enable::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::runtime.start.enable "$@"
}

step::runtime.start.enable() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=runtime.start_enable] Starting runtime service..."

  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      _start_containerd "${host}"
      ;;
    docker)
      _start_docker "${host}"
      ;;
    crio)
      _start_crio "${host}"
      ;;
    *)
      logger::error "[host=${host}] Unsupported runtime: ${runtime_type}"
      return 1
      ;;
  esac

  logger::info "[host=${host} step=runtime.start_enable] Runtime service started"
  return 0
}

_start_containerd() {
  local host="$1"

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl enable containerd"
  KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart containerd"

  # 等待 containerd 启动
  local max_attempts=10
  local attempt=0
  while [[ ${attempt} -lt ${max_attempts} ]]; do
    if KUBEXM_HOST="${host}" runner::remote_exec "ctr version" &>/dev/null; then
      logger::info "[host=${host}] Containerd is running"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  logger::error "[host=${host}] Containerd failed to start"
  return 1
}

_start_docker() {
  local host="$1"

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl enable docker"
  KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart docker"

  # 等待 docker 启动
  local max_attempts=10
  local attempt=0
  while [[ ${attempt} -lt ${max_attempts} ]]; do
    if KUBEXM_HOST="${host}" runner::remote_exec "docker info" &>/dev/null; then
      logger::info "[host=${host}] Docker is running"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  logger::error "[host=${host}] Docker failed to start"
  return 1
}

_start_crio() {
  local host="$1"

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl enable crio"
  KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart crio"

  # 等待 crio 启动
  local max_attempts=10
  local attempt=0
  while [[ ${attempt} -lt ${max_attempts} ]]; do
    if KUBEXM_HOST="${host}" runner::remote_exec "crictl info" &>/dev/null; then
      logger::info "[host=${host}] CRI-O is running"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  logger::error "[host=${host}] CRI-O failed to start"
  return 1
}

step::runtime.start.enable::check() {
  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      if runner::remote_exec "systemctl is-active containerd" &>/dev/null; then
        return 0  # 已运行，跳过
      fi
      ;;
    docker)
      if runner::remote_exec "systemctl is-active docker" &>/dev/null; then
        return 0  # 已运行，跳过
      fi
      ;;
    crio)
      if runner::remote_exec "systemctl is-active crio" &>/dev/null; then
        return 0  # 已运行，跳过
      fi
      ;;
  esac
  return 1  # 需要执行
}

step::runtime.start.enable::rollback() { return 0; }

step::runtime.start.enable::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
