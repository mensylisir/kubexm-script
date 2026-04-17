#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: runtime_dispatch_binary
# 分发容器运行时二进制文件
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

step::runtime.dispatch.binary::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::runtime.dispatch.binary "$@"
}

step::runtime.dispatch.binary() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=runtime.dispatch_binary] Dispatching runtime binary..."

  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      # 分发 containerd 二进制
      _dispatch_containerd_binary "${host}"
      ;;
    docker)
      # 分发 docker 二进制
      _dispatch_docker_binary "${host}"
      ;;
    crio)
      # 分发 crio 二进制
      _dispatch_crio_binary "${host}"
      ;;
    *)
      logger::error "[host=${host}] Unsupported runtime: ${runtime_type}"
      return 1
      ;;
  esac

  logger::info "[host=${host} step=runtime.dispatch_binary] Runtime binary dispatched"
  return 0
}

_dispatch_containerd_binary() {
  local host="$1"
  # 从 packages 分发 containerd 二进制
  KUBEXM_HOST="${host}" runner::remote_exec "mkdir -p /opt/kubexm/bin /opt/cri"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/containerd" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/containerd-shim" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/containerd-shim-runc-v1" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/containerd-shim-runc-v2" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/ctr" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_exec "chmod +x /opt/kubexm/bin/*"
}

_dispatch_docker_binary() {
  local host="$1"
  KUBEXM_HOST="${host}" runner::remote_exec "mkdir -p /opt/kubexm/bin"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/docker" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/dockerd" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/containerd" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/containerd-shim" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/docker-init" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/crictl" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_exec "chmod +x /opt/kubexm/bin/*"
}

_dispatch_crio_binary() {
  local host="$1"
  KUBEXM_HOST="${host}" runner::remote_exec "mkdir -p /opt/kubexm/bin"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/crio" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${KUBEXM_PACKAGES_DIR}/bin/crictl" "/opt/kubexm/bin/"
  KUBEXM_HOST="${host}" runner::remote_exec "chmod +x /opt/kubexm/bin/*"
}

step::runtime.dispatch.binary::check() {
  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      # 检查远程主机上的二进制，而非本地
      if runner::remote_exec "test -f /opt/kubexm/bin/containerd" &>/dev/null; then
        return 0  # 已安装，跳过
      fi
      ;;
    docker)
      if runner::remote_exec "test -f /opt/kubexm/bin/dockerd" &>/dev/null; then
        return 0  # 已安装，跳过
      fi
      ;;
    crio)
      if runner::remote_exec "test -f /opt/kubexm/bin/crio" &>/dev/null; then
        return 0  # 已安装，跳过
      fi
      ;;
  esac
  return 1  # 需要执行
}

step::runtime.dispatch.binary::rollback() { return 0; }

step::runtime.dispatch.binary::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
