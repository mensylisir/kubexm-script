#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KUBEXM_ROOT="${ROOT}"
source "${ROOT}/internal/pipeline/cluster/create.sh"

KUBEXM_DRY_RUN=true
pipeline::create_cluster "ctx" --cluster=test-01-kubeadm-single
