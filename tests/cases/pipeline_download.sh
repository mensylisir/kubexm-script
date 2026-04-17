#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KUBEXM_ROOT="${ROOT}"
source "${ROOT}/internal/pipeline/assets/download.sh"

KUBEXM_DRY_RUN=true
pipeline::download "ctx" --cluster=test-01-kubeadm-single
