#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Download Pipeline (在线/离线模式统一)
# ==============================================================================
# 职责：在有网络的环境下下载所有离线模式所需的资源
# 注意：download 不需要 host.yaml，因为只是在中心机器下载资源
# 离线模式：用户执行 kubexm download，然后将整个 packages 目录拷贝到离线环境
# 在线模式：kubexm create cluster 自动调用 download
# ==============================================================================

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/download.sh"

pipeline::download() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="download"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning download pipeline"
    return 0
  fi

  # 解析 cluster 参数（可选，用于确定下载哪些资源）
  local cluster_name=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done

  # 如果指定了 cluster，加载配置以确定下载内容
  if [[ -n "${cluster_name}" ]]; then
    export KUBEXM_CLUSTER_NAME="${cluster_name}"
    if [[ -f "${KUBEXM_CONFIG_FILE}" ]]; then
      parser::load_config
    fi
  fi

  # download 不校验 host.yaml（离线模式下可能还没有机器列表）
  module::download "${ctx}" "$@"
}