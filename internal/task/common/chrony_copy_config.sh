#!/usr/bin/env bash
set -euo pipefail

step::cluster.chrony.copy.config::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/chrony.conf"
}

step::cluster.chrony.copy.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local conf_file
  conf_file="$(context::get "chrony_conf_file")"

  runner::remote_copy_file "${conf_file}" "/etc/chrony.conf"
}

step::cluster.chrony.copy.config::rollback() { return 0; }

step::cluster.chrony.copy.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_hosts
}
