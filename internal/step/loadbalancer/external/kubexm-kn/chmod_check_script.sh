#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kn.chmod.check.script::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # chmod is idempotent, but we check if the file exists first
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/keepalived/check_nginx.sh"; then
    return 1  # file exists, need to chmod
  fi
  return 0  # file doesn't exist, skip
}

step::lb.external.kubexm.kn.chmod.check.script::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "chmod +x /etc/keepalived/check_nginx.sh"
}

step::lb.external.kubexm.kn.chmod.check.script::rollback() { return 0; }

step::lb.external.kubexm.kn.chmod.check.script::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
