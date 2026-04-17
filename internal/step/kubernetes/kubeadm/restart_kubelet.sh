#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: kubeadm.restart.kubelet
# 重启 kubelet 服务
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"

step::kubeadm.restart.kubelet::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::kubeadm.restart.kubelet "$@"
}

step::kubeadm.restart.kubelet() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=kubeadm.restart.kubelet] Restarting kubelet..."

  KUBEXM_HOST="${host}" runner::remote_exec "systemctl restart kubelet"

  logger::info "[host=${host} step=kubeadm.restart.kubelet] Kubelet restarted"
  return 0
}

step::kubeadm.restart.kubelet::check() {
  # 配置变更后总是需要重启
  return 1
}

step::kubeadm.restart.kubelet::rollback() { return 0; }

step::kubeadm.restart.kubelet::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
