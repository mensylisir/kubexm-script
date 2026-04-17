#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEXM_SCRIPT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${KUBEXM_SCRIPT_ROOT}/internal/config/domain/domain.sh"

# normalize compatibility mapping
[[ "$(domain::normalize_etcd_type external)" == "exists" ]]
[[ "$(domain::normalize_lb_type existing)" == "exists" ]]
[[ "$(domain::normalize_lb_type kubexm_kh)" == "kubexm-kh" ]]
[[ "$(domain::normalize_lb_type kubexm_kn)" == "kubexm-kn" ]]

# strategy semantics
[[ "$(domain::get_strategy_id kubeadm exists)" == "kubeadm-exists" ]]
[[ "$(domain::get_strategy_id kubexm exists)" == "kubexm-exists" ]]
domain::is_valid_strategy kubeadm exists
domain::is_valid_strategy kubexm exists
! domain::is_valid_strategy kubexm kubeadm

# loadbalancer semantics
domain::validate_lb_combination true exists exists kubeadm
! domain::validate_lb_combination true external exists kubeadm
domain::validate_lb_combination true external kubexm-kh kubeadm
