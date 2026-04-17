#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Task: Generate production configs (audit policy, encryption config)
# ==============================================================================
# 为 kubexm 和 kubeadm 模式生成生产必需的配置
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::generate_production_configs() {
  local ctx="$1"
  shift

  local cluster_name="${KUBEXM_CLUSTER_NAME:-default}"
  local packages_dir="${KUBEXM_PACKAGES_DIR:-${KUBEXM_ROOT}/packages}/${cluster_name}"
  mkdir -p "${packages_dir}"

  # 生成 audit policy
  source "${KUBEXM_ROOT}/internal/utils/kubeadm_config.sh"
  kubeadm::generate_audit_policy "${packages_dir}" || {
    log::error "Failed to generate audit policy"
    return 1
  }

  # 生成 encryption config
  kubeadm::generate_encryption_config "${packages_dir}" || {
    log::error "Failed to generate encryption config"
    return 1
  }

  log::info "Production configs generated in ${packages_dir}"
}

export -f task::generate_production_configs
