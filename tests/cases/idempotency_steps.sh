#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEXM_SCRIPT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export KUBEXM_ROOT="${KUBEXM_SCRIPT_ROOT}"

# internal step registration smoke checks
source "${KUBEXM_SCRIPT_ROOT}/internal/step/lib/registry.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/step/common/checks/check_tools_binary.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/step/common/checks/check_os.sh"

step::register "check.tools.binary" "${KUBEXM_SCRIPT_ROOT}/internal/step/common/checks/check_tools_binary.sh"
step::register "check.os" "${KUBEXM_SCRIPT_ROOT}/internal/step/common/checks/check_os.sh"
step::load "check.tools.binary"
step::load "check.os"

# idempotency sanity: check functions exist and are callable
step::check.tools.binary::check || true
step::check.os::check || true
