#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.docker.copy.binaries::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "docker" 2>/dev/null; then
    return 1
  fi

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "crictl" 2>/dev/null; then
    return 1
  fi

  if ! step::check::remote_command_exists "${KUBEXM_HOST}" "runc" 2>/dev/null; then
    return 1
  fi

  return 0
}

step::cluster.install.runtime.docker.copy.binaries::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local base_dir runc_version crictl_version arch docker_bins_dir
  base_dir="$(context::get "runtime_docker_base_dir" || true)"
  runc_version="$(context::get "runtime_docker_runc_version" || true)"
  crictl_version="$(context::get "runtime_docker_crictl_version" || true)"
  arch="$(context::get "runtime_docker_arch" || true)"
  docker_bins_dir="$(context::get "runtime_docker_bins_dir" || true)"

  runner::remote_exec "mkdir -p /usr/local/bin /usr/local/sbin /etc/systemd/system"

  if [[ -f "${base_dir}/crictl/${crictl_version}/${arch}/crictl" ]]; then
    runner::remote_copy_file "${base_dir}/crictl/${crictl_version}/${arch}/crictl" "/usr/local/bin/crictl"
    runner::remote_exec "chmod +x /usr/local/bin/crictl"
  fi

  if [[ -f "${base_dir}/runc/${runc_version}/${arch}/runc" ]]; then
    runner::remote_copy_file "${base_dir}/runc/${runc_version}/${arch}/runc" "/usr/local/sbin/runc"
    runner::remote_exec "chmod +x /usr/local/sbin/runc"
  fi

  if [[ -d "${docker_bins_dir}/docker" ]]; then
    local bin
    for bin in "${docker_bins_dir}/docker"/*; do
      [[ -f "${bin}" ]] || continue
      runner::remote_copy_file "${bin}" "/usr/bin/$(basename "${bin}")"
      runner::remote_exec "chmod +x /usr/bin/$(basename "${bin}")"
    done
  fi

  if [[ -f "${docker_bins_dir}/dockerd" ]]; then
    runner::remote_copy_file "${docker_bins_dir}/dockerd" "/usr/bin/dockerd"
    runner::remote_exec "chmod +x /usr/bin/dockerd"
  fi

  if [[ -f "${docker_bins_dir}/cri-dockerd" ]]; then
    runner::remote_copy_file "${docker_bins_dir}/cri-dockerd" "/usr/local/bin/cri-dockerd"
  elif [[ -f "${docker_bins_dir}/cri-dockerd/cri-dockerd" ]]; then
    runner::remote_copy_file "${docker_bins_dir}/cri-dockerd/cri-dockerd" "/usr/local/bin/cri-dockerd"
  fi
  runner::remote_exec "chmod +x /usr/local/bin/cri-dockerd >/dev/null 2>&1 || true"
}

step::cluster.install.runtime.docker.copy.binaries::rollback() { return 0; }

step::cluster.install.runtime.docker.copy.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
