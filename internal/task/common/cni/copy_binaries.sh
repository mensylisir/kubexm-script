#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.cni.copy.binaries::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "bridge" 2>/dev/null; then
    return 1
  fi

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "host-local" 2>/dev/null; then
    return 1
  fi

  return 0
}

step::cluster.install.cni.copy.binaries::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local cni_dir
  cni_dir="$(context::get "cni_install_dir" || true)"

  runner::remote_exec "mkdir -p /opt/cni/bin"
  local f
  for f in "${cni_dir}"/*; do
    [[ -f "${f}" ]] || continue
    runner::remote_copy_file "${f}" "/opt/cni/bin/$(basename "${f}")"
    runner::remote_exec "chmod +x /opt/cni/bin/$(basename "${f}")"
  done

  log::info "CNI binaries installed on ${KUBEXM_HOST}"
}

step::cluster.install.cni.copy.binaries::rollback() { return 0; }

step::cluster.install.cni.copy.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
