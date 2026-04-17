#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/internal/logger/logger.sh"

stdout_file="/tmp/kubexm-log-stdout-$$"
stderr_file="/tmp/kubexm-log-stderr-$$"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not available"
  exit 0
fi

KUBEXM_TASK_ID="t-1" KUBEXM_PIPELINE_NAME="p-1" KUBEXM_RUN_ID="r-1" KUBEXM_STEP_NAME="s-1" KUBEXM_HOST="h-1" \
  logger::info "test message" >"${stdout_file}" 2>"${stderr_file}"

# JSON stdout contains required keys
jq -e '.task_id=="t-1" and .pipeline_name=="p-1" and .run_id=="r-1" and .step_name=="s-1" and .host=="h-1" and .msg=="test message"' "${stdout_file}" >/dev/null

# stderr contains human-readable line
grep -q "\[INFO\] test message" "${stderr_file}"

rm -f "${stdout_file}" "${stderr_file}"
