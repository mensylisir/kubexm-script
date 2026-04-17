#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.defaults.cni::check() { return 1; }

step::manifests.show.defaults.cni::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  echo "  CNI配置 (Calico):"
  echo "    - 网络模式: $(defaults::get_calico_network_mode) (适合混合网络)"
  echo "    - BlockSize: $(defaults::get_calico_blocksize) (对应 /$(defaults::get_calico_blocksize) 子网)"
  echo "    - MTU: $(defaults::get_calico_mtu)"
  echo "    - IPIP模式: $(defaults::get_calico_ipip_mode) (使用$(defaults::get_calico_network_mode))"
  echo
}

step::manifests.show.defaults.cni::rollback() { return 0; }

step::manifests.show.defaults.cni::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
