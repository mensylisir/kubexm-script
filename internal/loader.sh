#!/usr/bin/env bash
set -euo pipefail
KUBEXM_INTERNAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
source "${KUBEXM_INTERNAL_ROOT}/context/context.sh"
source "${KUBEXM_INTERNAL_ROOT}/logger/logger.sh"
source "${KUBEXM_INTERNAL_ROOT}/errors/errors.sh"
source "${KUBEXM_INTERNAL_ROOT}/parser/parser.sh"
source "${KUBEXM_INTERNAL_ROOT}/runner/runner.sh"
source "${KUBEXM_INTERNAL_ROOT}/connector/connector.sh"
source "${KUBEXM_INTERNAL_ROOT}/progress/progress.sh"
