#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: runtime_restart_service
# 重启容器运行时服务（用于配置变更后）
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

step::runtime.restart.service::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::runtime.restart.service "$@"
}

step::runtime.restart.service() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=runtime.restart_service] Restarting runtime service..."

  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart containerd"
      ;;
    docker)
      KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart docker"
      ;;
    crio)
      KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart crio"
      ;;
    *)
      logger::error "[host=${host}] Unsupported runtime: ${runtime_type}"
      return 1
      ;;
  esac

  logger::info "[host=${host} step=runtime.restart_service] Runtime service restarted"
  return 0
}

step::runtime.restart.service::check() {
  # 配置变更后总是需要重启
  return 1
}

step::runtime.restart.service::rollback() { return 0; }

step::runtime.restart.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
