#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KUBEXM_ROOT="${ROOT}"
export KUBEXM_BIN_PATH="${ROOT}/bin/kubexm"
source "${ROOT}/internal/pipeline/cluster/upgrade_cluster.sh"
source "${ROOT}/internal/task/cluster/upgrade_cluster.sh"

KUBEXM_DRY_RUN=true
pipeline::upgrade_cluster "ctx" --cluster=test-01-kubeadm-single --to-version=v1.33.0
