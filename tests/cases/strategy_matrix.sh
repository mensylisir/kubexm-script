#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEXM_SCRIPT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${KUBEXM_SCRIPT_ROOT}/internal/config/domain/domain.sh"

[[ "$(domain::get_strategy_id kubeadm kubeadm)" == "kubeadm-kubeadm" ]]
[[ "$(domain::get_strategy_id kubeadm kubexm)" == "kubeadm-kubexm" ]]
[[ "$(domain::get_strategy_id kubeadm exists)" == "kubeadm-exists" ]]
[[ "$(domain::get_strategy_id kubexm kubexm)" == "kubexm-kubexm" ]]
[[ "$(domain::get_strategy_id kubexm exists)" == "kubexm-exists" ]]

domain::is_valid_strategy kubeadm kubeadm
domain::is_valid_strategy kubeadm kubexm
domain::is_valid_strategy kubeadm exists
domain::is_valid_strategy kubexm kubexm
domain::is_valid_strategy kubexm exists
domain::is_valid_strategy kubexm kubeadm
