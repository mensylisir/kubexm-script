#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Scale Cluster Pipeline (Router)
# ==============================================================================
# Routes to scale-out or scale-in based on host.yaml changes
# ==============================================================================

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/pipeline/cluster/scaleout_cluster.sh"
source "${KUBEXM_ROOT}/internal/pipeline/cluster/scalein_cluster.sh"

pipeline::scale_cluster() {
  local ctx="$1"
  shift

  KUBEXM_PIPELINE_NAME="scale.cluster"

  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning scale cluster pipeline"
    return 0
  fi

  # ============================================================================
  # Parameter parsing
  # ============================================================================
  local cluster_name=""
  local action=""
  local role=""
  local nodes=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --action=*)
        action="${arg#*=}"
        ;;
      --role=*)
        role="${arg#*=}"
        ;;
      --nodes=*)
        nodes="${arg#*=}"
        ;;
    esac
  done

  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for scale cluster"
    return 2
  fi

  # ============================================================================
  # Environment setup
  # ============================================================================
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  
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

  # ============================================================================
  # Determine scaling direction if not explicitly specified
  # ============================================================================
  if [[ -z "${action}" ]]; then
    # Try to auto-detect based on node count changes
    # This is a heuristic - user should specify --action for clarity
    logger::warn "No --action specified, attempting auto-detection..."
    logger::warn "Recommended: use --action=scale-out or --action=scale-in for clarity"

    # Check if we can determine from context or default to showing help
    logger::error "Cannot auto-detect scale direction. Please specify:"
    logger::error "  --action=scale-out  (add nodes)"
    logger::error "  --action=scale-in   (remove nodes)"
    logger::error ""
    logger::error "Example:"
    logger::error "  kubexm scale cluster --cluster=${cluster_name} --action=scale-out"
    logger::error "  kubexm scale cluster --cluster=${cluster_name} --action=scale-in"
    return 2
  fi

  # ============================================================================
  # Route to appropriate pipeline
  # ============================================================================
  case "${action}" in
    scale-out|scaleout|out|add)
      logger::info "Routing to scale-out pipeline..."
      pipeline::scaleout_cluster_main "${ctx}" "$@"
      ;;

    scale-in|scalein|in|remove|delete)
      logger::info "Routing to scale-in pipeline..."
      pipeline::scalein_cluster_main "${ctx}" "$@"
      ;;

    *)
      logger::error "Unknown action: ${action}"
      logger::error "Valid actions: scale-out, scale-in"
      return 2
      ;;
  esac
}

export -f pipeline::scale_cluster
