#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

output="$(KUBEXM_ROOT="${ROOT}" KUBEXM_DRY_RUN=true bash ${ROOT}/bin/kubexm create cluster --cluster=test-01-kubeadm-single 2>/dev/null || true)"
[[ "${output}" == *"DRY-RUN"* ]]
