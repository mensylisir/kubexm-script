#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KUBEXM_ROOT="${ROOT}"
export KUBEXM_BIN_PATH="${ROOT}/bin/kubexm"
source "${ROOT}/internal/pipeline/cluster/upgrade_etcd.sh"

KUBEXM_DRY_RUN=true
pipeline::upgrade_etcd "ctx" --cluster=test-01-kubeadm-single --to-version=3.5.15
