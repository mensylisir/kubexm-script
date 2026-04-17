#!/usr/bin/env bash
set -euo pipefail

step::runtime.cri.dockerd.delete.files::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/usr/local/bin/cri-dockerd" 2>/dev/null; then
    return 1  # file exists, need to delete
  fi
  return 0  # file doesn't exist, skip
}

step::runtime.cri.dockerd.delete.files::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Deleting cri-dockerd files from ${KUBEXM_HOST}..."

  # Remove binaries
  runner::remote_exec "rm -f /usr/local/bin/cri-dockerd 2>/dev/null || true"

  # Remove systemd service
  runner::remote_exec "systemctl stop cri-dockerd >/dev/null 2>&1 || true"
  runner::remote_exec "systemctl disable cri-dockerd >/dev/null 2>&1 || true"
  runner::remote_exec "rm -f /etc/systemd/system/cri-dockerd.service 2>/dev/null || true"
  runner::remote_exec "systemctl daemon-reload"

  log::info "cri-dockerd files deleted from ${KUBEXM_HOST}"
}

step::runtime.cri.dockerd.delete.files::rollback() { return 0; }

step::runtime.cri.dockerd.delete.files::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}