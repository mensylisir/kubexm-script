#!/usr/bin/env bash
set -euo pipefail

step::download.tools.binaries::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  checkpoint::is_done "tools_binaries" && return 0
  return 1
}

step::download.tools.binaries::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/resources/download.sh"
  source "${KUBEXM_ROOT}/internal/utils/common.sh"
  source "${KUBEXM_ROOT}/internal/utils/binary_bom.sh"

  download::init_context

  local output_dir="${DOWNLOAD_DIR}/tools"
  mkdir -p "${output_dir}"

  log::info "Downloading common tool binaries into ${output_dir}"
  utils::binary::bom::download_common_tools "${DOWNLOAD_ARCH_LIST}" "${output_dir}"
  download::ensure_skopeo || true
  checkpoint::save "tools_binaries"
}

step::download.tools.binaries::rollback() { return 0; }

step::download.tools.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
