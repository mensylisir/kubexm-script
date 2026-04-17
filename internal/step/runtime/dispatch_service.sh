#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: runtime_dispatch_service
# 分发容器运行时 Systemd 服务文件
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"
source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

step::runtime.dispatch.service::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::runtime.dispatch.service "$@"
}

step::runtime.dispatch.service() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=runtime.dispatch_service] Dispatching runtime service..."

  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      _dispatch_containerd_service "${host}"
      ;;
    docker)
      _dispatch_docker_service "${host}"
      ;;
    crio)
      _dispatch_crio_service "${host}"
      ;;
    *)
      logger::error "[host=${host}] Unsupported runtime: ${runtime_type}"
      return 1
      ;;
  esac

  logger::info "[host=${host} step=runtime.dispatch_service] Runtime service dispatched"
  return 0
}

_dispatch_containerd_service() {
  local host="$1"

  context::render_template "${host}" \
    "${KUBEXM_ROOT}/templates/runtime/containerd/containerd.service.tmpl" \
    "/etc/systemd/system/containerd.service"

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl daemon-reload"
}

_dispatch_docker_service() {
  local host="$1"

  context::render_template "${host}" \
    "${KUBEXM_ROOT}/templates/runtime/docker/docker.service.tmpl" \
    "/etc/systemd/system/docker.service"

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl daemon-reload"
}

_dispatch_crio_service() {
  local host="$1"

  context::render_template "${host}" \
    "${KUBEXM_ROOT}/templates/runtime/crio/crio.service.tmpl" \
    "/etc/systemd/system/crio.service"

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl daemon-reload"
}

step::runtime.dispatch.service::check() {
  local runtime_type service_file
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      service_file="/etc/systemd/system/containerd.service"
      ;;
    docker)
      service_file="/etc/systemd/system/docker.service"
      ;;
    crio)
      service_file="/etc/systemd/system/crio.service"
      ;;
    *)
      return 1
      ;;
  esac

  if step::check::remote_file_exists "${KUBEXM_HOST}" "${service_file}" && \
     runner::remote_exec "grep -q '^ExecStart=' ${service_file}" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

step::runtime.dispatch.service::rollback() { return 0; }

step::runtime.dispatch.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
