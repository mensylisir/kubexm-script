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

pipeline::scaleout_precheck() {
  local ctx="${1:-}"
  module::preflight_connectivity_permissive "${ctx}" "$@" || return $?
  task::cluster::validate "${ctx}" "$@"
}

pipeline::scaleout_workers() {
  local ctx="${1:-}"
  logger::info "[Pipeline:scaleout] Adding workers"
  task::collect_workers_info "${ctx}" "$@"
  task::collect_workers_join_cmd "${ctx}" "$@"
  task::join_workers "${ctx}" "$@"
  task::wait_nodes_ready "${ctx}" "$@"
}

pipeline::scaleout_control_plane() {
  local ctx="${1:-}"
  logger::info "[Pipeline:scaleout] Adding control plane"
  task::scale_out_cp "${ctx}" "$@"
}

pipeline::scaleout_etcd() {
  local ctx="${1:-}"
  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  # 仅 kubexm 类型的独立 ETCD 节点需要单独扩容
  if [[ "${etcd_type}" == "kubexm" ]]; then
    logger::info "[Pipeline:scaleout] Adding etcd nodes"
    
    # Check current etcd member count before adding
    local current_count=0
    if command -v etcdctl &>/dev/null; then
      current_count=$(ETCDCTL_API=3 etcdctl member list \
        --endpoints="https://127.0.0.1:2379" \
        --cacert="/etc/kubernetes/pki/etcd/ca.crt" \
        --cert="/etc/kubernetes/pki/etcd/healthcheck-client.crt" \
        --key="/etc/kubernetes/pki/etcd/healthcheck-client.key" \
        2>/dev/null | wc -l || echo "0")
    fi
    
    module::etcd_install "${ctx}" "$@" || return $?
    
    # Warn if new count is even
    if [[ ${current_count} -gt 0 ]]; then
      local new_count=$((current_count + 1))
      if [[ $((new_count % 2)) -eq 0 ]]; then
        logger::warn "⚠️  WARNING: ETCD cluster now has ${new_count} members (even number)"
        logger::warn "   Consider adding one more ETCD node for optimal fault tolerance"
      fi
    fi
  else
    logger::info "[Pipeline:scaleout] Skipping etcd scale-out (etcd is stacked or external)"
  fi
}

pipeline::scaleout_post() {
  local ctx="${1:-}"
  task::scale_update_hosts "${ctx}" "$@"
}

pipeline::scaleout_cluster() {
  local ctx="${1:-}"

  # Initialize progress tracking (5 steps)
  pipeline::init_progress 5

  pipeline::step_start "PreCheck"
  logger::info "[Pipeline:scaleout] PreCheck: validating cluster state..."
  pipeline::scaleout_precheck "${ctx}" "$@" || { pipeline::step_fail "PreCheck"; return $?; }
  pipeline::step_complete "PreCheck"

  pipeline::step_start "ControlPlane"
  logger::info "[Pipeline:scaleout] ControlPlane: adding control plane nodes..."
  pipeline::scaleout_control_plane "${ctx}" "$@" || { pipeline::step_fail "ControlPlane"; return $?; }
  # Register actual rollback to remove failed control-plane nodes
  pipeline::register_rollback "Remove newly added control-plane nodes" \
    "logger::warn 'Rolling back: removing failed control-plane nodes'; task::scale_cp_remove_nodes '${ctx}' '$@' --action=scale-in || logger::warn 'Control-plane node removal failed, manual cleanup may be needed'"
  pipeline::step_complete "ControlPlane"

  pipeline::step_start "Etcd"
  logger::info "[Pipeline:scaleout] Etcd: adding etcd nodes..."
  pipeline::scaleout_etcd "${ctx}" "$@" || { pipeline::step_fail "Etcd"; return $?; }
  # ETCD rollback is complex - warn user but attempt member removal
  pipeline::register_rollback "Remove newly added etcd members" \
    "logger::warn 'Rolling back: removing etcd members'; module::etcd_delete '${ctx}' '$@' || logger::warn 'ETCD member removal failed, verify quorum manually'"
  pipeline::step_complete "Etcd"

  pipeline::step_start "Workers"
  logger::info "[Pipeline:scaleout] Workers: adding worker nodes..."
  pipeline::scaleout_workers "${ctx}" "$@" || { pipeline::step_fail "Workers"; return $?; }
  # Register actual rollback to remove failed worker nodes
  pipeline::register_rollback "Remove newly added worker nodes" \
    "logger::warn 'Rolling back: removing failed worker nodes'; task::cluster.scale.remove.nodes '${ctx}' '$@' --action=scale-in || logger::warn 'Worker node removal failed, manual cleanup may be needed'"
  pipeline::step_complete "Workers"

  pipeline::step_start "PostScale"
  logger::info "[Pipeline:scaleout] PostScale: updating hosts and configurations..."
  pipeline::scaleout_post "${ctx}" "$@" || { pipeline::step_fail "PostScale"; return $?; }
  pipeline::step_complete "PostScale"

  pipeline::summary
  logger::info "[Pipeline:scaleout] Scale-out completed successfully!"
  return 0
}

pipeline::scaleout_cluster_main() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="scaleout.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning scale-out cluster pipeline"
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
    logger::error "missing required --cluster for scale-out cluster"
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
  # 配置验证（扩容前验证配置一致性）
  # ============================================================================
  logger::info "[Pipeline] Validating configuration consistency..."
  config::validate_consistency || {
    logger::error "Configuration validation failed. Aborting scale-out."
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

  # 如果指定了 --role，仅扩容指定角色
  if [[ -n "${target_role}" ]]; then
    logger::info "[Pipeline] Single-role scale-out: ${target_role}"
    # Initialize progress for single-role scaling (2 steps: role + post)
    pipeline::init_progress 2
    
    case "${target_role}" in
      worker)
        pipeline::step_start "Workers"
        pipeline::scaleout_workers "${ctx}" "$@" || { pipeline::step_fail "Workers"; return $?; }
        pipeline::step_complete "Workers"
        ;;
      control-plane|master)
        pipeline::step_start "ControlPlane"
        pipeline::scaleout_control_plane "${ctx}" "$@" || { pipeline::step_fail "ControlPlane"; return $?; }
        pipeline::step_complete "ControlPlane"
        ;;
      etcd)
        pipeline::step_start "Etcd"
        pipeline::scaleout_etcd "${ctx}" "$@" || { pipeline::step_fail "Etcd"; return $?; }
        pipeline::step_complete "Etcd"
        ;;
      *)
        logger::error "Unknown role: ${target_role}. Supported: worker, control-plane, etcd"
        return 2
        ;;
    esac
    
    pipeline::step_start "PostScale"
    pipeline::scaleout_post "${ctx}" "$@" || { pipeline::step_fail "PostScale"; return $?; }
    pipeline::step_complete "PostScale"
    
    pipeline::summary
  else
    # 默认全部扩容
    pipeline::scaleout_cluster "${ctx}" "$@"
  fi

  # 成功完成，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  logger::info "[Pipeline:scaleout] Scale-out completed successfully!"
  return 0
}