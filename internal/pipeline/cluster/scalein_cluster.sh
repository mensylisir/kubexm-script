#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/module/etcd.sh"
source "${KUBEXM_ROOT}/internal/task/common/validate.sh"
source "${KUBEXM_ROOT}/internal/task/common/scale_hosts.sh"
source "${KUBEXM_ROOT}/internal/task/common/scale_control_plane.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"

pipeline::scalein_precheck() {
  local ctx="${1:-}"
  module::preflight_connectivity_permissive "${ctx}" "$@" || return $?
  task::cluster::validate "${ctx}" "$@"
}

pipeline::scalein_workers() {
  local ctx="${1:-}"
  logger::info "[Pipeline:scalein] Removing worker nodes"
  task::drain_workers "${ctx}" "$@"
  task::stop_kubelet_workers "${ctx}" "$@"
  task::kubeadm_reset_workers "${ctx}" "$@"
  task::cleanup_dirs_workers "${ctx}" "$@"
  task::flush_iptables "${ctx}" "$@"
  task::update_lb_config "${ctx}" "$@"
}

pipeline::scalein_control_plane() {
  local ctx="${1:-}"
  logger::info "[Pipeline:scalein] Removing control plane nodes"
  task::scale_in_cp "${ctx}" "$@"
}

pipeline::scalein_etcd() {
  local ctx="${1:-}"
  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  # 仅 kubexm 类型的独立 ETCD 节点需要单独缩容
  if [[ "${etcd_type}" == "kubexm" ]]; then
    logger::info "[Pipeline:scalein] Removing etcd nodes"
    module::etcd_delete "${ctx}" "$@" || return $?
  else
    logger::info "[Pipeline:scalein] Skipping etcd scale-in (etcd is stacked or external)"
  fi
}

pipeline::scalein_post() {
  local ctx="${1:-}"
  task::scale_update_hosts "${ctx}" "$@"
}

pipeline::scalein_cluster() {
  local ctx="${1:-}"

  # Initialize progress tracking (6 steps)
  pipeline::init_progress 6

  pipeline::step_start "PreCheck"
  logger::info "[Pipeline:scalein] PreCheck: validating cluster state..."
  pipeline::scalein_precheck "${ctx}" "$@" || { pipeline::step_fail "PreCheck"; return $?; }
  pipeline::step_complete "PreCheck"

  # Quorum checks before removal (safety first!)
  pipeline::step_start "QuorumCheck"
  logger::info "[Pipeline:scalein] Validating quorum requirements before removal..."
  
  # Check ETCD quorum if removing etcd nodes
  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  if [[ "${etcd_type}" == "kubexm" ]]; then
    # Count etcd nodes to be removed from host.yaml
    local etcd_to_remove
    etcd_to_remove=$(yq '.spec.hosts[] | select(.roles[] == "etcd") | .name' "${KUBEXM_HOST_FILE}" 2>/dev/null | wc -l || echo "0")
    if [[ ${etcd_to_remove} -gt 0 ]]; then
      pipeline::validate_quorum_before_removal "etcd" "${etcd_to_remove}" || { pipeline::step_fail "QuorumCheck"; return $?; }
    fi
  fi

  # Check control-plane quorum
  local cp_to_remove
  cp_to_remove=$(yq '.spec.hosts[] | select(.roles[] == "control-plane" or .roles[] == "master") | .name' "${KUBEXM_HOST_FILE}" 2>/dev/null | wc -l || echo "0")
  if [[ ${cp_to_remove} -gt 0 ]]; then
    pipeline::validate_quorum_before_removal "control-plane" "${cp_to_remove}" || { pipeline::step_fail "QuorumCheck"; return $?; }
  fi
  pipeline::step_complete "QuorumCheck"

  pipeline::step_start "Workers"
  logger::info "[Pipeline:scalein] Workers: removing worker nodes..."
  pipeline::scalein_workers "${ctx}" "$@" || { pipeline::step_fail "Workers"; return $?; }
  pipeline::step_complete "Workers"

  pipeline::step_start "ControlPlane"
  logger::info "[Pipeline:scalein] ControlPlane: removing control plane nodes..."
  pipeline::scalein_control_plane "${ctx}" "$@" || { pipeline::step_fail "ControlPlane"; return $?; }
  pipeline::step_complete "ControlPlane"

  pipeline::step_start "Etcd"
  logger::info "[Pipeline:scalein] Etcd: removing etcd nodes..."
  pipeline::scalein_etcd "${ctx}" "$@" || { pipeline::step_fail "Etcd"; return $?; }
  pipeline::step_complete "Etcd"

  pipeline::step_start "PostScale"
  logger::info "[Pipeline:scalein] PostScale: updating hosts and configurations..."
  pipeline::scalein_post "${ctx}" "$@" || { pipeline::step_fail "PostScale"; return $?; }
  pipeline::step_complete "PostScale"

  pipeline::summary
  logger::info "[Pipeline:scalein] Scale-in completed successfully!"
  return 0
}

pipeline::scalein_cluster_main() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="scalein.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning scale-in cluster pipeline"
    return 0
  fi

  local cluster_name=""
  local target_role=""
  local nodes=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --role=*)
        target_role="${arg#*=}"
        ;;
      --nodes=*)
        nodes="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for scale-in cluster"
    return 2
  fi

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
  # 配置验证（缩容前验证配置一致性）
  # ============================================================================
  logger::info "[Pipeline] Validating configuration consistency..."
  config::validate_consistency || {
    logger::error "Configuration validation failed. Aborting scale-in."
    return 1
  }

  # 如果指定了 --nodes，传递给下游用于精确选择节点
  if [[ -n "${nodes}" ]]; then
    export KUBEXM_SCALE_NODES="${nodes}"
  fi

  # ============================================================================
  # 获取集群锁 + 启动超时监控
  # ============================================================================
  pipeline::start_timeout_watchdog
  pipeline::acquire_lock "${cluster_name}" 300 || { pipeline::stop_timeout_watchdog; return 1; }
  trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog; pipeline::_rollback_all' EXIT

  # 如果指定了 --role，仅缩容指定角色
  if [[ -n "${target_role}" ]]; then
    logger::info "[Pipeline] Single-role scale-in: ${target_role}"
    # Initialize progress for single-role scaling (2 steps: role + post)
    pipeline::init_progress 2
    
    case "${target_role}" in
      worker)
        pipeline::step_start "Workers"
        pipeline::scalein_workers "${ctx}" "$@" || { pipeline::step_fail "Workers"; return $?; }
        pipeline::step_complete "Workers"
        ;;
      control-plane|master)
        pipeline::step_start "ControlPlane"
        pipeline::scalein_control_plane "${ctx}" "$@" || { pipeline::step_fail "ControlPlane"; return $?; }
        pipeline::step_complete "ControlPlane"
        ;;
      etcd)
        pipeline::step_start "Etcd"
        pipeline::scalein_etcd "${ctx}" "$@" || { pipeline::step_fail "Etcd"; return $?; }
        pipeline::step_complete "Etcd"
        ;;
      *)
        logger::error "Unknown role: ${target_role}. Supported: worker, control-plane, etcd"
        return 2
        ;;
    esac
    
    pipeline::step_start "PostScale"
    pipeline::scalein_post "${ctx}" "$@" || { pipeline::step_fail "PostScale"; return $?; }
    pipeline::step_complete "PostScale"
    
    pipeline::summary
  else
    # 默认全部缩容
    pipeline::scalein_cluster "${ctx}" "$@"
  fi

  # 成功完成，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  logger::info "[Pipeline:scalein] Scale-in completed successfully!"
  return 0
}