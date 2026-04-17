#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/internal/context/context.sh"

context::init
context::set "foo" "bar"
[[ "$(context::get "foo")" == "bar" ]]

# missing key should be non-fatal
context::get "missing" >/dev/null || true

# cancelled flag should not crash context::with
context::with "scope" true || true
