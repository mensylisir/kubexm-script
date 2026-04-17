#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KUBEXM_ROOT="${ROOT}"
export KUBEXM_BIN_PATH="${ROOT}/bin/kubexm"
source "${ROOT}/internal/pipeline/cluster/delete.sh"

KUBEXM_DRY_RUN=true
pipeline::delete_cluster "ctx" --cluster=test-01-kubeadm-single
