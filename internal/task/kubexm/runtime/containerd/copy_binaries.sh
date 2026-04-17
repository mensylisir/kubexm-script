#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.containerd.copy.binaries::check() {
  # 检查关键二进制是否存在
  # 返回 0 表示已满足（跳过执行），返回 1 表示未满足（需要执行）
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

  # 检查 crictl
  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "crictl" 2>/dev/null; then
    return 1
  fi

  # 检查 runc
  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "runc" 2>/dev/null; then
    return 1
  fi

  # 检查 containerd
  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "containerd" 2>/dev/null; then
    return 1
  fi

  return 0
}

step::cluster.install.runtime.containerd.copy.binaries::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local base_dir runc_version crictl_version arch cdir
  base_dir="$(context::get "runtime_containerd_base_dir" || true)"
  runc_version="$(context::get "runtime_containerd_runc_version" || true)"
  crictl_version="$(context::get "runtime_containerd_crictl_version" || true)"
  arch="$(context::get "runtime_containerd_arch" || true)"
  cdir="$(context::get "runtime_containerd_bin_dir" || true)"

  runner::remote_exec "mkdir -p /usr/local/bin /usr/local/sbin /etc/systemd/system"

  if [[ -f "${base_dir}/crictl/${crictl_version}/${arch}/crictl" ]]; then
    runner::remote_copy_file "${base_dir}/crictl/${crictl_version}/${arch}/crictl" "/usr/local/bin/crictl"
    runner::remote_exec "chmod +x /usr/local/bin/crictl"
  fi

  if [[ -f "${base_dir}/runc/${runc_version}/${arch}/runc" ]]; then
    runner::remote_copy_file "${base_dir}/runc/${runc_version}/${arch}/runc" "/usr/local/sbin/runc"
    runner::remote_exec "chmod +x /usr/local/sbin/runc"
  fi

  local f
  for f in "${cdir}"/*; do
    [[ -f "${f}" ]] || continue
    [[ "${f}" == *.tar.gz ]] && continue
    runner::remote_copy_file "${f}" "/usr/local/bin/$(basename "${f}")"
    runner::remote_exec "chmod +x /usr/local/bin/$(basename "${f}")"
  done
}

step::cluster.install.runtime.containerd.copy.binaries::rollback() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "rm -f /usr/local/bin/crictl /usr/local/sbin/runc /usr/local/bin/containerd /usr/local/bin/containerd-shim /usr/local/bin/containerd-shim-runc-v2 /usr/local/bin/containerd-shim-runc-v1 /usr/local/bin/ctr 2>/dev/null || true"
}

step::cluster.install.runtime.containerd.copy.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
