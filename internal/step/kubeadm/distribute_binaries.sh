#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.binaries.kubexm::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "kubexm" 2>/dev/null; then
    return 1
  fi

  return 0
}

step::kubernetes.distribute.binaries.kubexm::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local node_name base_dir components
  node_name="$(context::get "kubernetes_kubexm_binaries_node_name" || true)"
  base_dir="$(context::get "kubernetes_kubexm_binaries_base_dir" || true)"
  components="$(context::get "kubernetes_kubexm_binaries_components" || true)"

  runner::remote_exec "mkdir -p /usr/local/bin"

  local comp
  for comp in ${components}; do
    local src
    src="${base_dir}/${comp}"
    if [[ ! -f "${src}" ]]; then
      log::error "Missing binary: ${src}"
      return 1
    fi
    runner::remote_copy_file "${src}" "/usr/local/bin/${comp}"
    runner::remote_exec "chmod +x /usr/local/bin/${comp}"
  done

  runner::remote_exec "ln -sf /usr/local/bin/kubelet /usr/bin/kubelet >/dev/null 2>&1 || true"
  log::info "Kubernetes binaries (kubexm) distributed to ${KUBEXM_HOST}"
}

step::kubernetes.distribute.binaries.kubexm::rollback() { return 0; }

step::kubernetes.distribute.binaries.kubexm::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
