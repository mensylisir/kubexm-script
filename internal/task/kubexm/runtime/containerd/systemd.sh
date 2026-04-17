#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.containerd.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_service_running "${KUBEXM_HOST}" "containerd"
}

step::cluster.install.runtime.containerd.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl daemon-reload && systemctl enable containerd && systemctl restart containerd"
  log::info "Runtime containerd installed on ${KUBEXM_HOST}"
}

step::cluster.install.runtime.containerd.systemd::rollback() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl stop containerd 2>/dev/null || true; systemctl disable containerd 2>/dev/null || true"
}

step::cluster.install.runtime.containerd.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
