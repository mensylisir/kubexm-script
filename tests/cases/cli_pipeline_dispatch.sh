#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

output="$(KUBEXM_ROOT="${ROOT}" bash ${ROOT}/bin/kubexm help 2>/dev/null || true)"
[[ "${output}" == *"Usage"* || "${output}" == *"用法"* ]]
