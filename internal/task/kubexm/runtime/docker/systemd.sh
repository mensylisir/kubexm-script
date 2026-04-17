#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.docker.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_service_running "${KUBEXM_HOST}" "docker"
}

step::cluster.install.runtime.docker.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl daemon-reload && systemctl enable docker && systemctl restart docker"
  runner::remote_exec "systemctl enable cri-dockerd && systemctl restart cri-dockerd"
  log::info "Runtime docker installed on ${KUBEXM_HOST}"
}

step::cluster.install.runtime.docker.systemd::rollback() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "systemctl stop docker cri-dockerd 2>/dev/null || true; systemctl disable docker cri-dockerd 2>/dev/null || true"
}

step::cluster.install.runtime.docker.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
