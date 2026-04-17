#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.crio.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_service_running "${KUBEXM_HOST}" "crio"
}

step::cluster.install.runtime.crio.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl daemon-reload && systemctl enable crio && systemctl restart crio"
  log::info "Runtime crio installed on ${KUBEXM_HOST}"
}

step::cluster.install.runtime.crio.systemd::rollback() { return 0; }

step::cluster.install.runtime.crio.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
