#!/usr/bin/env bash
set -euo pipefail

# 配置依赖：统一在文件顶部加载
source "${KUBEXM_ROOT}/internal/logger/log.sh"
source "${KUBEXM_ROOT}/internal/config/config.sh"

cni::prepare() {
  local cluster_name="$1"
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  local first_master
  first_master=$(config::get_role_members 'control-plane' | awk '{print $1}')
  export CNI_FIRST_MASTER="${first_master}"
  export CNI_POD_CIDR="$(config::get_pod_cidr)"
  export CNI_SERVICE_CIDR="$(config::get_service_cidr)"
  export CNI_KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"
}

export -f cni::prepare
