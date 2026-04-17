#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export KUBEXM_ROOT="${ROOT}"
export KUBEXM_CLUSTER_NAME="test-01-kubeadm-single"

source "${ROOT}/internal/parser/parser.sh"
source "${ROOT}/internal/config/config.sh"

parser::load_config
yaml_val="$(config::get_kubernetes_version)"

export KUBEXM_KUBERNETES_VERSION="v9.9.9"
parser::load_config
env_val="${KUBEXM_KUBERNETES_VERSION}"

unset KUBEXM_KUBERNETES_VERSION
parser::load_config
revert_val="$(config::get_kubernetes_version)"

[[ "${yaml_val}" != "${env_val}" ]]
[[ "${revert_val}" == "${yaml_val}" ]]
