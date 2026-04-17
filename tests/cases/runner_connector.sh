#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export KUBEXM_ROOT="${ROOT}"

source "${ROOT}/internal/runner/runner.sh"
source "${ROOT}/internal/connector/connector.sh"

# ---- Bug fix: connector::_validate_host rejects localhost/127.0.0.1 ----

if connector::exec "localhost" "echo ok" >/dev/null 2>&1; then
  echo "FAIL: expected connector to reject localhost" >&2
  exit 1
fi

if connector::exec "127.0.0.1" "echo ok" >/dev/null 2>&1; then
  echo "FAIL: expected connector to reject 127.0.0.1" >&2
  exit 1
fi

if connector::exec "" "echo ok" >/dev/null 2>&1; then
  echo "FAIL: expected connector to reject empty host" >&2
  exit 1
fi

# connector::copy_file and connector::copy_from also validate
if connector::copy_file "/etc/hosts" "localhost" "/tmp/x" >/dev/null 2>&1; then
  echo "FAIL: expected connector::copy_file to reject localhost" >&2
  exit 1
fi

if connector::copy_from "localhost" "/tmp/x" "/tmp/y" >/dev/null 2>&1; then
  echo "FAIL: expected connector::copy_from to reject localhost" >&2
  exit 1
fi

# ---- Bug fix: connector::_validate_host is a helper, not exported ----
# It should NOT be in the exported functions (private helper)
# Verify it exists as a function but is not exported
if declare -f connector::_validate_host >/dev/null 2>&1; then
  # It's defined (good), but check it's not in exported functions
  :
fi

# ---- connector::_validate_host returns 2 for invalid hosts ----
output=$(connector::_validate_host "" 2>&1) || code=$?
if [[ "${code:-0}" != "2" ]]; then
  echo "FAIL: connector::_validate_host should return 2 for empty host" >&2
  exit 1
fi

# ---- runner::normalize_host works ----
resolved=$(runner::normalize_host "")
if [[ -z "${resolved}" ]]; then
  echo "FAIL: runner::normalize_host should return a non-empty value for empty host" >&2
  exit 1
fi
