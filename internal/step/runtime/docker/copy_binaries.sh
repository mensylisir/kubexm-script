#!/usr/bin/env bash
set -euo pipefail

step::runtime.cri.dockerd.copy.binaries::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/usr/local/bin/cri-dockerd" 2>/dev/null; then
    return 0  # already exists, skip
  fi
  return 1  # need to copy
}

step::runtime.cri.dockerd.copy.binaries::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local bin_dir arch version cri_dockerd_tarball
  bin_dir="$(context::get "runtime_cri_dockerd_bin_dir" || true)"
  arch="$(context::get "runtime_cri_dockerd_arch" || true)"
  version="0.3.4"

  if [[ -z "${bin_dir}" ]]; then
    log::error "Missing cri_dockerd_bin_dir in context"
    return 1
  fi

  log::info "Copying cri-dockerd binaries to ${KUBEXM_HOST}..."
  runner::remote_exec "mkdir -p /usr/local/bin"

  cri_dockerd_tarball="${bin_dir}/cri-dockerd-${version}-${arch}.tar.gz"
  if [[ -f "${cri_dockerd_tarball}" ]]; then
    runner::remote_copy_file "${cri_dockerd_tarball}" "/tmp/cri-dockerd.tar.gz"
    runner::remote_exec "tar -xzf /tmp/cri-dockerd.tar.gz -C /tmp && cp /tmp/cri-dockerd /usr/local/bin/ && chmod +x /usr/local/bin/cri-dockerd && rm -rf /tmp/cri-dockerd*"
  else
    log::error "cri-dockerd tarball not found: ${cri_dockerd_tarball}"
    return 1
  fi

  log::info "cri-dockerd binaries copied"
}

step::runtime.cri.dockerd.copy.binaries::rollback() { return 0; }

step::runtime.cri.dockerd.copy.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}