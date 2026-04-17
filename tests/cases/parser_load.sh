#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export KUBEXM_ROOT="${ROOT}"
export KUBEXM_CLUSTER_NAME="test-01-kubeadm-single"

source "${ROOT}/internal/parser/parser.sh"

parser::load_config >/dev/null
parser::load_hosts >/dev/null
