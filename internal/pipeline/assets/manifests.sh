#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/manifests.sh"

pipeline::manifests() {
  local ctx="$1"
  shift || true
  KUBEXM_PIPELINE_NAME="manifests"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning manifests pipeline"
    return 0
  fi
  module::manifests "${ctx}" "$@"
}