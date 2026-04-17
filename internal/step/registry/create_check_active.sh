#!/usr/bin/env bash
set -euo pipefail

step::registry.create.check.active::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::remote_exec "systemctl is-active registry >/dev/null 2>&1"
}

step::registry.create.check.active::run() { return 0; }

step::registry.create.check.active::rollback() { return 0; }

step::registry.create.check.active::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
