#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: runtime_install_crictl
# 安装并配置 crictl 调试工具
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

step::runtime.install.crictl::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::runtime.install.crictl "$@"
}

step::runtime.install.crictl() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=runtime.install_crictl] Installing crictl..."

  # crictl 已在 dispatch_binary 时分发，这里配置
  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      _configure_crictl_containerd "${host}"
      ;;
    docker)
      _configure_crictl_docker "${host}"
      ;;
    crio)
      _configure_crictl_crio "${host}"
      ;;
  esac

  logger::info "[host=${host} step=runtime.install_crictl] crictl installed"
  return 0
}

_configure_crictl_containerd() {
  local host="$1"

  # 生成 crictl 配置
  local sandbox_image
  sandbox_image=$(config::get_sandbox_image)

  KUBEXM_HOST="${host}" runner::remote_exec "cat > /etc/crictl.yaml << 'ENDOFHEREDOC'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
pull-image-on-create: true
ENDOFHEREDOC"

  # 配置 containerd 为 cgroup driver
  KUBEXM_HOST="${host}" runner::remote_exec "mkdir -p /etc/containerd"
  KUBEXM_HOST="${host}" runner::remote_exec "containerd config default > /etc/containerd/config.toml 2>/dev/null || true"
}

_configure_crictl_docker() {
  local host="$1"

  KUBEXM_HOST="${host}" runner::remote_exec "cat > /etc/crictl.yaml << 'ENDOFHEREDOC'
runtime-endpoint: unix:///var/run/docker.sock
image-endpoint: unix:///var/run/docker.sock
timeout: 10
debug: false
ENDOFHEREDOC"
}

_configure_crictl_crio() {
  local host="$1"

  KUBEXM_HOST="${host}" runner::remote_exec "cat > /etc/crictl.yaml << 'ENDOFHEREDOC'
runtime-endpoint: unix:///var/run/crio/crio.sock
image-endpoint: unix:///var/run/crio/crio.sock
timeout: 10
debug: false
ENDOFHEREDOC"
}

step::runtime.install.crictl::check() {
  # 检查远程主机上的 crictl 配置，而非本地
  if runner::remote_exec "test -f /etc/crictl.yaml" &>/dev/null; then
    return 0  # 已配置，跳过
  fi
  return 1  # 需要执行
}

step::runtime.install.crictl::rollback() { return 0; }

step::runtime.install.crictl::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
