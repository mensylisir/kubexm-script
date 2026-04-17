#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Domain Aggregator
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

if [[ "${KUBEXM_DOMAIN_LOADED:-0}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi
export KUBEXM_DOMAIN_LOADED=1

KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

source "${KUBEXM_SCRIPT_ROOT}/internal/config/domain/enums.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/domain/normalize.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/domain/rules/strategy_rules.sh"
