#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Create Cluster Pipeline
# ==============================================================================
# 按照分层模型编排：
# 1. Preflight Module - 系统预检（OSInit, TimeSync）
# 2. Infrastructure Module - 基础设施（LoadBalancer, PKI）
# 3. Runtime Module - 容器运行时
# 4. ETCD Module - 数据库（仅 kubexm 类型）
# 5. Kubernetes Core Module - 控制面/节点
# 6. Network Module - CNI 网络
# 7. PostInstall Module - Addons + SmokeTest
# ==============================================================================

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/module/certs.sh"
source "${KUBEXM_ROOT}/internal/module/lb.sh"
source "${KUBEXM_ROOT}/internal/module/runtime.sh"
source "${KUBEXM_ROOT}/internal/module/etcd.sh"
source "${KUBEXM_ROOT}/internal/module/kubernetes.sh"
source "${KUBEXM_ROOT}/internal/module/kubeadm.sh"
source "${KUBEXM_ROOT}/internal/module/kubexm.sh"
source "${KUBEXM_ROOT}/internal/module/cni.sh"
source "${KUBEXM_ROOT}/internal/module/addons.sh"
source "${KUBEXM_ROOT}/internal/task/common/smoke/smoke_test.sh"
source "${KUBEXM_ROOT}/internal/module/registry.sh"
source "${KUBEXM_ROOT}/internal/module/images.sh"
source "${KUBEXM_ROOT}/internal/module/cluster_config.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"
source "${KUBEXM_ROOT}/internal/utils/retry.sh"

pipeline::create_cluster() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="create.cluster"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning create cluster pipeline"
    return 0
  fi

  # ============================================================================
  # 参数解析
  # ============================================================================
  local cluster_name=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for create cluster"
    return 2
  fi

  # 启动超时监控
  pipeline::start_timeout_watchdog
  # 初始化进度 (9 个主要步骤: Preflight, Certs, LoadBalancer, Runtime, ETCD[optional], Kubernetes, CNI, Addons, SmokeTest)
  pipeline::init_progress 9

  # ============================================================================
  # 环境准备
  # ============================================================================
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  
  # 强制更新配置文件路径（因为KUBEXM_CLUSTER_NAME刚刚设置）
  KUBEXM_CONFIG_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/config.yaml"
  KUBEXM_HOST_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/host.yaml"
  export KUBEXM_CONFIG_FILE KUBEXM_HOST_FILE
  
  # 重新加载配置以更新文件路径（因为KUBEXM_CLUSTER_NAME刚刚设置）
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  
  if [[ ! -f "${KUBEXM_CONFIG_FILE}" ]]; then
    logger::error "config.yaml not found: ${KUBEXM_CONFIG_FILE}"
    pipeline::stop_timeout_watchdog
    return 1
  fi
  if [[ ! -f "${KUBEXM_HOST_FILE}" ]]; then
    logger::error "host.yaml not found: ${KUBEXM_HOST_FILE}"
    pipeline::stop_timeout_watchdog
    return 1
  fi
  
  # 获取集群锁（防止并发操作同一集群）- 在配置文件验证后获取
  pipeline::acquire_lock "${cluster_name}" 300 || { pipeline::stop_timeout_watchdog; return 1; }
  trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog; pipeline::_rollback_all' EXIT
  
  parser::load_config
  parser::load_hosts

  # ============================================================================
  # 配置验证（创建前验证配置一致性）
  # ============================================================================
  logger::info "[Pipeline] Validating configuration consistency..."
  config::validate_consistency || {
    logger::error "Configuration validation failed. Aborting cluster creation."
    return 1
  }

  # ============================================================================
  # 收集配置目录（设置 context 变量，供后续模块使用）
  # ============================================================================
  module::cluster_collect_config "${ctx}" "$@" || return $?

  # ============================================================================
  # 在线模式：下载资源
  # ============================================================================
  local mode
  mode=$(config::get_mode 2>/dev/null || echo "offline")
  local registry_created="false"
  if [[ "${mode}" == "online" ]]; then
    pipeline::step_start "Download"
    logger::info "[Pipeline] Downloading resources..."
    # Retry download with exponential backoff (3 attempts, 5s base delay)
    if ! retry::module 3 5 module::download "${ctx}" "$@"; then
      logger::error "Failed to download resources after retries"
      pipeline::step_fail "Download"
      return $?
    fi
    pipeline::step_complete "Download"
    export KUBEXM_SKIP_DOWNLOAD="true"
  else
    local registry_enabled
    registry_enabled=$(config::get_registry_enabled 2>/dev/null || echo "false")
    if [[ "${registry_enabled}" == "true" ]]; then
      pipeline::step_start "Registry"
      logger::info "[Pipeline] Creating container registry..."
      module::registry_create "${ctx}" "$@" || { pipeline::step_fail "Registry"; return $?; }
      registry_created="true"
      pipeline::register_rollback "Remove Registry" "module::registry_delete '${ctx}' || logger::warn 'Registry cleanup failed'"
      
      logger::info "[Pipeline] Pushing images to registry (with retry)..."
      # Retry image push with exponential backoff (3 attempts, 10s base delay for large images)
      if ! retry::module 3 10 module::push_images "${ctx}" "$@" --packages; then
        logger::error "Failed to push images to registry after retries"
        pipeline::step_fail "Registry"
        # Cleanup registry on failure
        if [[ "${registry_created}" == "true" ]]; then
          logger::warn "Cleaning up registry..."
          module::registry_delete "${ctx}" "$@" || logger::warn "Registry cleanup failed"
        fi
        return 1
      fi
      pipeline::step_complete "Registry"
    fi
  fi

  # ============================================================================
  # Module 1: Preflight - 连通性检查 + 系统预检
  # ============================================================================
  pipeline::step_start "Preflight"
  logger::info "[Pipeline] Module: preflight"
  # Retry connectivity check (network can be flaky)
  if ! retry::module 3 5 module::preflight_connectivity_strict "${ctx}" "$@"; then
    logger::error "Connectivity check failed after retries - verify network and SSH access"
    pipeline::step_fail "Preflight"
    return $?
  fi
  module::preflight "${ctx}" "$@" || { pipeline::step_fail "Preflight"; return $?; }
  pipeline::step_complete "Preflight"

  # ============================================================================
  # Module 2: Certs - 证书管理
  # ============================================================================
  pipeline::step_start "Certs"
  logger::info "[Pipeline] Module: certs"
  module::certs_init "${ctx}" "$@" || { pipeline::step_fail "Certs"; return $?; }
  pipeline::step_complete "Certs"

  # ============================================================================
  # Module 3: LoadBalancer - 负载均衡
  # ============================================================================
  pipeline::step_start "LoadBalancer"
  logger::info "[Pipeline] Module: loadbalancer"
  # Retry LB installation (may involve package downloads)
  if ! retry::module 2 5 module::lb_install "${ctx}" "$@"; then
    logger::error "LoadBalancer installation failed after retries"
    pipeline::step_fail "LoadBalancer"
    return $?
  fi
  pipeline::register_rollback "Remove LoadBalancer" "module::lb_delete '${ctx}' || true"
  pipeline::step_complete "LoadBalancer"

  # ============================================================================
  # Module 4: Runtime - 容器运行时
  # ============================================================================
  pipeline::step_start "Runtime"
  logger::info "[Pipeline] Module: runtime"
  module::runtime_collect_config "${ctx}" "$@" || { pipeline::step_fail "Runtime"; return $?; }
  # Retry runtime installation (involves package downloads and service starts)
  if ! retry::module 2 5 module::runtime_install "${ctx}" "$@"; then
    logger::error "Runtime installation failed after retries"
    pipeline::step_fail "Runtime"
    return $?
  fi
  pipeline::register_rollback "Remove Runtime" "module::runtime_delete '${ctx}' || true"
  pipeline::step_complete "Runtime"

  # ============================================================================
  # Module 5: ETCD - 数据库（仅 kubexm 类型）
  # ============================================================================
  local etcd_type
  etcd_type=$(config::get_etcd_type)
  if [[ "${etcd_type}" == "kubexm" ]]; then
    pipeline::step_start "ETCD"
    logger::info "[Pipeline] Module: etcd"
    module::etcd_install "${ctx}" "$@" || { pipeline::step_fail "ETCD"; return $?; }
    pipeline::register_rollback "Remove ETCD" "module::etcd_delete '${ctx}' || true"
    pipeline::step_complete "ETCD"
  fi

  # ============================================================================
  # Module 6: Kubernetes - 控制面/节点
  # ============================================================================
  pipeline::step_start "Kubernetes"
  logger::info "[Pipeline] Module: kubernetes"
  module::kubernetes_install "${ctx}" "$@" || { pipeline::step_fail "Kubernetes"; return $?; }
  pipeline::register_rollback "Reset Kubernetes" "task::kubeadm::reset '${ctx}' || true"
  pipeline::step_complete "Kubernetes"

  # ============================================================================
  # Module 7: Network - CNI
  # ============================================================================
  pipeline::step_start "CNI"
  logger::info "[Pipeline] Module: network (cni)"
  module::cni_collect_config "${ctx}" "$@" || { pipeline::step_fail "CNI"; return $?; }
  module::cni_render "${ctx}" "$@" || { pipeline::step_fail "CNI"; return $?; }
  module::cni_install_binaries "${ctx}" "$@" || { pipeline::step_fail "CNI"; return $?; }
  module::cni_install "${ctx}" "$@" || { pipeline::step_fail "CNI"; return $?; }
  pipeline::register_rollback "Remove CNI" "module::cni_delete '${ctx}' || true"
  pipeline::step_complete "CNI"

  # ============================================================================
  # Module 8: Addons - 插件
  # ============================================================================
  pipeline::step_start "Addons"
  logger::info "[Pipeline] Module: addons"
  module::addons_collect_config "${ctx}" "$@" || { pipeline::step_fail "Addons"; return $?; }
  module::addons_render "${ctx}" "$@" || { pipeline::step_fail "Addons"; return $?; }
  module::addons_install "${ctx}" "$@" || { pipeline::step_fail "Addons"; return $?; }
  module::addons_cert_renew "${ctx}" "$@" || { pipeline::step_fail "Addons"; return $?; }
  module::addons_etcd_backup "${ctx}" "$@" || { pipeline::step_fail "Addons"; return $?; }
  pipeline::register_rollback "Remove Addons" "module::addons_delete '${ctx}' || true"
  pipeline::step_complete "Addons"

  # ============================================================================
  # Module 9: SmokeTest - 冒烟测试
  # ============================================================================
  pipeline::step_start "SmokeTest"
  logger::info "[Pipeline] Module: smoke_test"
  task::smoke_test "${ctx}" "$@" || { pipeline::step_fail "SmokeTest"; return $?; }
  pipeline::step_complete "SmokeTest"

  # 成功完成，清空回滚栈，释放锁
  pipeline::clear_rollback_stack
  trap - EXIT
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  pipeline::summary
  logger::info "[Pipeline] Cluster created successfully!"
  return 0
}