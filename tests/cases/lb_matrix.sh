#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEXM_SCRIPT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${KUBEXM_SCRIPT_ROOT}/internal/config/domain/domain.sh"

# internal mode
domain::validate_lb_combination true internal haproxy kubeadm
domain::validate_lb_combination true internal nginx kubexm
! domain::validate_lb_combination true internal kubexm-kh kubeadm >/dev/null 2>&1

# external mode
domain::validate_lb_combination true external kubexm-kh kubeadm
domain::validate_lb_combination true external kubexm-kn kubexm
! domain::validate_lb_combination true external haproxy kubeadm >/dev/null 2>&1

# kube-vip
domain::validate_lb_combination true kube-vip kube-vip kubeadm

# exists
domain::validate_lb_combination true exists exists kubeadm
