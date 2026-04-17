#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Reconfigure Cluster Pipeline
# ==============================================================================
# 重新渲染配置并应用（不重新安装）：
# 1. runtime_reconfigure - 运行时配置重载
# 2. etcd_reconfigure - etcd 配置重载
# 3. cni_reconfigure - CNI 配置重载
# 4. lb_reconfigure - LoadBalancer 配置重载
# 5. addons_reconfigure - Addons 配置重载
# 6. hosts - 更新 /etc/hosts
# ==============================================================================

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/module/runtime.sh"
source "${KUBEXM_ROOT}/internal/module/cni.sh"
source "${KUBEXM_ROOT}/internal/module/lb.sh"
source "${KUBEXM_ROOT}/internal/module/addons.sh"
source "${KUBEXM_ROOT}/internal/module/etcd.sh"
source "${KUBEXM_ROOT}/internal/module/os.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"

pipeline::reconfigure_cluster() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="reconfigure.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning reconfigure pipeline"
    return 0
  fi

  # ============================================================================
  # 参数解析
  # ============================================================================
  local cluster_name=""
  local target=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --target=*)
        target="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for reconfigure"
    return 2
  fi

  # ============================================================================
  # 环境准备
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
  # 配置验证（重配置前验证配置一致性）
  # ============================================================================
  logger::info "[Pipeline] Validating configuration consistency..."
  config::validate_consistency || {
    logger::error "Configuration validation failed. Aborting reconfigure."
    return 1
  }

  # ============================================================================
  # 获取集群锁 + 启动超时监控（reconfigure是高危写操作）
  # ============================================================================
  pipeline::start_timeout_watchdog
  pipeline::acquire_lock "${cluster_name}" 300 || { pipeline::stop_timeout_watchdog; return 1; }
  trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog' EXIT

  # ============================================================================
  # 执行重配置流程
  # ============================================================================
  # 连通性检查（宽松模式，允许部分节点不可达）
  module::preflight_connectivity_permissive "${ctx}" "$@" || return $?

  if [[ -z "${target}" || "${target}" == "all" ]]; then
    logger::info "[Pipeline] Reconfiguring all components..."

    # Initialize progress tracking (6 steps)
    pipeline::init_progress 6

    pipeline::step_start "RuntimeReconfigure"
    logger::info "[Pipeline] Reconfiguring runtime..."
    module::runtime_reconfigure "${ctx}" "$@" || { pipeline::step_fail "RuntimeReconfigure"; return $?; }
    pipeline::step_complete "RuntimeReconfigure"

    pipeline::step_start "EtcdReconfigure"
    logger::info "[Pipeline] Reconfiguring etcd..."
    module::etcd_reconfigure "${ctx}" "$@" || { pipeline::step_fail "EtcdReconfigure"; return $?; }
    pipeline::step_complete "EtcdReconfigure"

    pipeline::step_start "CNIReconfigure"
    logger::info "[Pipeline] Reconfiguring CNI..."
    module::cni_reconfigure "${ctx}" "$@" || { pipeline::step_fail "CNIReconfigure"; return $?; }
    pipeline::step_complete "CNIReconfigure"

    pipeline::step_start "LBReconfigure"
    logger::info "[Pipeline] Reconfiguring LoadBalancer..."
    module::lb_reconfigure "${ctx}" "$@" || { pipeline::step_fail "LBReconfigure"; return $?; }
    pipeline::step_complete "LBReconfigure"

    pipeline::step_start "AddonsReconfigure"
    logger::info "[Pipeline] Reconfiguring Addons..."
    module::addons_reconfigure "${ctx}" "$@" || { pipeline::step_fail "AddonsReconfigure"; return $?; }
    pipeline::step_complete "AddonsReconfigure"

    pipeline::step_start "HostsUpdate"
    logger::info "[Pipeline] Reconfiguring hosts..."
    module::os_update_hosts "${ctx}" "$@" || { pipeline::step_fail "HostsUpdate"; return $?; }
    pipeline::step_complete "HostsUpdate"

    pipeline::summary
    logger::info "[Pipeline] Reconfigure completed successfully!"
  else
    # Single target reconfiguration
    pipeline::init_progress 1
    
    case "${target}" in
      runtime)
        pipeline::step_start "RuntimeReconfigure"
        module::runtime_reconfigure "${ctx}" "$@" || { pipeline::step_fail "RuntimeReconfigure"; return $?; }
        pipeline::step_complete "RuntimeReconfigure"
        ;;
      etcd)
        pipeline::step_start "EtcdReconfigure"
        module::etcd_reconfigure "${ctx}" "$@" || { pipeline::step_fail "EtcdReconfigure"; return $?; }
        pipeline::step_complete "EtcdReconfigure"
        ;;
      cni)
        pipeline::step_start "CNIReconfigure"
        module::cni_reconfigure "${ctx}" "$@" || { pipeline::step_fail "CNIReconfigure"; return $?; }
        pipeline::step_complete "CNIReconfigure"
        ;;
      lb|loadbalancer)
        pipeline::step_start "LBReconfigure"
        module::lb_reconfigure "${ctx}" "$@" || { pipeline::step_fail "LBReconfigure"; return $?; }
        pipeline::step_complete "LBReconfigure"
        ;;
      addons)
        pipeline::step_start "AddonsReconfigure"
        module::addons_reconfigure "${ctx}" "$@" || { pipeline::step_fail "AddonsReconfigure"; return $?; }
        pipeline::step_complete "AddonsReconfigure"
        ;;
      hosts)
        pipeline::step_start "HostsUpdate"
        module::os_update_hosts "${ctx}" "$@" || { pipeline::step_fail "HostsUpdate"; return $?; }
        pipeline::step_complete "HostsUpdate"
        ;;
      *)
        logger::error "Unknown target: ${target}"
        return 1
        ;;
    esac
    
    pipeline::summary
  fi

  # 成功完成，清空回滚栈，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  logger::info "[Pipeline] Reconfigure completed successfully!"
  return 0
}
