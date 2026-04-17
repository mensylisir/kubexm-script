#!/usr/bin/env bash
set -euo pipefail

step::registry.create.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_service_running "${KUBEXM_HOST}" "registry"
}

step::registry.create.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::remote_exec "systemctl daemon-reload && systemctl enable registry && systemctl restart registry"
}

step::registry.create.systemd::rollback() { return 0; }

step::registry.create.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
