#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Health Check Pipeline
# ==============================================================================
# 编排健康检查：
# 1. node_health - 节点健康检查
# 2. component_health - 组件健康检查 (kubelet, kube-proxy, etcd)
# 3. workload_health - 工作负载健康检查
# 4. connectivity - 连接性检查
# ==============================================================================

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/task/health/main.sh"
source "${KUBEXM_ROOT}/internal/task/health/json_output.sh"

pipeline::health_cluster() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="health.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning health check pipeline"
    return 0
  fi

  # ============================================================================
  # 参数解析
  # ============================================================================
  local cluster_name=""
  local check_type="all"
  local output_format="text"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --check=*)
        check_type="${arg#*=}"
        ;;
      --output-format=*)
        output_format="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for health check"
    return 2
  fi

  # ============================================================================
  # 环境准备
  # ============================================================================
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  export KUBEXM_HEALTH_OUTPUT_FORMAT="${output_format}"
  
  # 强制更新配置文件路径（因为KUBEXM_CLUSTER_NAME刚刚设置）
  KUBEXM_CONFIG_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/config.yaml"
  KUBEXM_HOST_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/host.yaml"
  export KUBEXM_CONFIG_FILE KUBEXM_HOST_FILE
  
  if [[ ! -f "${KUBEXM_CONFIG_FILE}" ]]; then
    logger::error "config.yaml not found: ${KUBEXM_CONFIG_FILE}"
    return 1
  fi
  if [[ ! -f "${KUBEXM_HOST_FILE}" ]]; then
    logger::error "host.yaml not found: ${KUBEXM_HOST_FILE}"
    return 1
  fi
  parser::load_config
  parser::load_hosts

  module::preflight_connectivity_permissive "${ctx}" "$@" || return $?

  # ============================================================================
  # 执行健康检查流程
  # ============================================================================
  local exit_code=0
  case "${check_type}" in
    all)
      task::health_check_all "${ctx}" "$@" || exit_code=$?
      ;;
    node)
      task::health_check_nodes "${ctx}" "$@" || exit_code=$?
      ;;
    component)
      task::health_check_components "${ctx}" "$@" || exit_code=$?
      ;;
    workload)
      task::health_check_workloads "${ctx}" "$@" || exit_code=$?
      ;;
    connectivity)
      task::health_check_connectivity "${ctx}" "$@" || exit_code=$?
      ;;
    *)
      logger::error "Unknown check type: ${check_type}"
      return 1
      ;;
  esac

  # 如果请求 JSON 输出，生成结构化结果
  if [[ "${output_format}" == "json" ]]; then
    health::output_json "${check_type}" "${exit_code}"
  fi

  return "${exit_code}"
}