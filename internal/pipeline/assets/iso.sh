#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/iso.sh"

pipeline::iso() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="create.iso"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning iso pipeline"
    return 0
  fi
  module::iso_build "${ctx}" "$@"
}