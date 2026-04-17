#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for path in \
  internal/loader.sh \
  internal/context/context.sh \
  internal/logger/logger.sh \
  internal/errors/errors.sh \
  internal/parser/parser.sh; do
  [[ -f "${ROOT}/${path}" ]] || { echo "missing ${path}"; exit 1; }
done
