#!/usr/bin/env bash
set -euo pipefail

step::registry.create.copy.binary::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_command_exists "${KUBEXM_HOST}" "registry"
}

step::registry.create.copy.binary::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local bin_src
  bin_src="$(context::get "registry_create_bin_src" || true)"
  runner::remote_copy_file "${bin_src}" "/usr/local/bin/registry"
  runner::remote_exec "chmod +x /usr/local/bin/registry"
}

step::registry.create.copy.binary::rollback() { return 0; }

step::registry.create.copy.binary::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
