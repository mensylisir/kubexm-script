#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.crio.copy.binaries::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "crio" 2>/dev/null; then
    return 1
  fi

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "crictl" 2>/dev/null; then
    return 1
  fi

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "runc" 2>/dev/null; then
    return 1
  fi

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "conmon" 2>/dev/null; then
    return 1
  fi

  return 0
}

step::cluster.install.runtime.crio.copy.binaries::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local base_dir runc_version crictl_version arch crio_dir
  base_dir="$(context::get "runtime_crio_base_dir" || true)"
  runc_version="$(context::get "runtime_crio_runc_version" || true)"
  crictl_version="$(context::get "runtime_crio_crictl_version" || true)"
  arch="$(context::get "runtime_crio_arch" || true)"
  crio_dir="$(context::get "runtime_crio_bin_dir" || true)"

  runner::remote_exec "mkdir -p /usr/local/bin /usr/local/sbin /etc/systemd/system"

  if [[ -f "${base_dir}/crictl/${crictl_version}/${arch}/crictl" ]]; then
    runner::remote_copy_file "${base_dir}/crictl/${crictl_version}/${arch}/crictl" "/usr/local/bin/crictl"
    runner::remote_exec "chmod +x /usr/local/bin/crictl"
  fi

  if [[ -f "${base_dir}/runc/${runc_version}/${arch}/runc" ]]; then
    runner::remote_copy_file "${base_dir}/runc/${runc_version}/${arch}/runc" "/usr/local/sbin/runc"
    runner::remote_exec "chmod +x /usr/local/sbin/runc"
  fi

  if [[ -f "${crio_dir}/crio" ]]; then
    runner::remote_copy_file "${crio_dir}/crio" "/usr/local/bin/crio"
  elif [[ -f "${crio_dir}/crio/crio" ]]; then
    runner::remote_copy_file "${crio_dir}/crio/crio" "/usr/local/bin/crio"
  fi
  runner::remote_exec "chmod +x /usr/local/bin/crio >/dev/null 2>&1 || true"

  if [[ -f "${crio_dir}/conmon" ]]; then
    runner::remote_copy_file "${crio_dir}/conmon" "/usr/local/bin/conmon"
  elif [[ -f "${crio_dir}/conmon/conmon" ]]; then
    runner::remote_copy_file "${crio_dir}/conmon/conmon" "/usr/local/bin/conmon"
  fi
  runner::remote_exec "chmod +x /usr/local/bin/conmon >/dev/null 2>&1 || true"
}

step::cluster.install.runtime.crio.copy.binaries::rollback() { return 0; }

step::cluster.install.runtime.crio.copy.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
