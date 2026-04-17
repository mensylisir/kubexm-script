#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cp.cleanup.dirs::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_cp_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip
  fi
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # 如果节点不可达，跳过
  if ! step::check::host_reachable 5; then
    return 0
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/etc/kubernetes"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/var/lib/kubelet"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/var/lib/etcd"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/root/.kube"; then
    return 1
  fi
  return 0  # no dirs to cleanup, skip
}

step::cluster.scale.cp.cleanup.dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube >/dev/null 2>&1 || true"
}

step::cluster.scale.cp.cleanup.dirs::rollback() { return 0; }

step::cluster.scale.cp.cleanup.dirs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}