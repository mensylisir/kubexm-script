#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Certificate Rotation Module
# ==============================================================================
# 零停机证书轮转实现
# 支持 kubeadm 和 kubexm 两种部署模式
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取脚本目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
KUBEXM_ROOT="${KUBEXM_ROOT:-$KUBEXM_SCRIPT_ROOT}"

# 加载依赖
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/pki.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/kubeconfig.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/runner/runner.sh"

# ==============================================================================
# 目录结构常量
# ==============================================================================
readonly ROTATION_OLD_DIR="old"
readonly ROTATION_NEW_DIR="new"
readonly ROTATION_BUNDLE_DIR="bundle"

# ==============================================================================
# 远程执行封装（通过 Runner，禁止直接调用 Connector/SSH）
# ==============================================================================

rotation::with_host() {
  local host="$1"
  shift
  local prev_host="${KUBEXM_HOST:-}"
  KUBEXM_HOST="$(runner::normalize_host "${host}")" || return 2
  "$@"
  local rc=$?
  if [[ -n "${prev_host}" ]]; then
    KUBEXM_HOST="${prev_host}"
  else
    unset KUBEXM_HOST
  fi
  return ${rc}
}

rotation::remote_exec() {
  local host="$1"
  local cmd="$2"
  rotation::with_host "${host}" runner::remote_exec "${cmd}"
}

rotation::remote_copy_file() {
  local host="$1"
  local src="$2"
  local dest="$3"
  rotation::with_host "${host}" runner::remote_copy_file "${src}" "${dest}"
}

rotation::remote_copy_from() {
  local host="$1"
  local src="$2"
  local dest="$3"
  rotation::with_host "${host}" runner::remote_copy_from "${src}" "${dest}"
}

# ==============================================================================
# 验证函数
# ==============================================================================

rotation::get_etcd_type() {
  config::get_etcd_type 2>/dev/null || defaults::get_etcd_type
}

rotation::resolve_etcd_cert_dir() {
  local etcd_type
  etcd_type="$(rotation::get_etcd_type)"
  if [[ "${etcd_type}" == "kubeadm" ]]; then
    echo "/etc/kubernetes/pki/etcd"
  else
    echo "/etc/etcd/ssl"
  fi
}

#######################################
# 验证证书链
# Arguments:
#   $1 - 证书文件路径
#   $2 - CA 证书路径
# Returns:
#   0 验证通过, 1 失败
#######################################
rotation::verify_cert_chain() {
  local cert_file="$1"
  local ca_file="$2"

  if [[ ! -f "${cert_file}" ]] || [[ ! -f "${ca_file}" ]]; then
    log::error "Certificate or CA file not found"
    return 1
  fi

  if openssl verify -CAfile "${ca_file}" "${cert_file}" >/dev/null 2>&1; then
    log::success "Certificate chain verified: ${cert_file}"
    return 0
  else
    log::error "Certificate chain verification failed: ${cert_file}"
    return 1
  fi
}

#######################################
# 验证 bundle CA 包含两个证书
# Arguments:
#   $1 - CA bundle 文件路径
# Returns:
#   0 验证通过, 1 失败
#######################################
rotation::verify_bundle_ca() {
  local bundle_ca="$1"

  if [[ ! -f "${bundle_ca}" ]]; then
    log::error "Bundle CA file not found: ${bundle_ca}"
    return 1
  fi

  local cert_count
  cert_count=$(grep -c "BEGIN CERTIFICATE" "${bundle_ca}" 2>/dev/null || echo "0")

  if [[ "${cert_count}" -eq 2 ]]; then
    log::success "Bundle CA contains 2 certificates: ${bundle_ca}"
    return 0
  else
    log::error "Bundle CA should contain 2 certificates, found: ${cert_count}"
    return 1
  fi
}

# ==============================================================================
# Etcd 健康检查
# ==============================================================================

#######################################
# Etcd 健康检查
# Arguments:
#   $1 - 节点IP
#   $2 - 部署类型 (kubeadm|kubexm)
#   $3 - 超时秒数 (默认60)
# Returns:
#   0 健康, 1 不健康
#######################################
rotation::check_etcd_health() {
  local node_ip="$1"
  local etcd_type="${2:-$(rotation::get_etcd_type)}"
  local timeout="${3:-$(defaults::get_command_timeout)}"

  log::info "Checking etcd health on ${node_ip}..."

  local etcd_cert_dir
  etcd_cert_dir="$(rotation::resolve_etcd_cert_dir)"

  local check_cmd="ETCDCTL_API=3 etcdctl endpoint health \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=${etcd_cert_dir}/ca.crt \
    --cert=${etcd_cert_dir}/server.crt \
    --key=${etcd_cert_dir}/server.key"

  local elapsed=0
  while [[ ${elapsed} -lt ${timeout} ]]; do
    if rotation::remote_exec "${node_ip}" "${check_cmd}" >/dev/null 2>&1; then
      log::success "Etcd is healthy on ${node_ip}"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    log::info "  Waiting for etcd... (${elapsed}s/${timeout}s)"
  done

  log::error "Etcd health check timeout on ${node_ip}"
  return 1
}

#######################################
# Etcd Quorum-aware 重启
# Arguments:
#   $1 - etcd节点列表 (空格分隔)
#   $2 - 部署类型 (kubeadm|kubexm)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::restart_etcd_with_health_check() {
  local etcd_nodes="$1"
  local etcd_type="${2:-$(rotation::get_etcd_type)}"

  log::info "Restarting etcd cluster with health checks..."

  for node in ${etcd_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node}" 2>/dev/null || echo "${node}")
    
    log::info "Restarting etcd on ${node} (${node_ip})..."
    
    if [[ "${etcd_type}" == "kubeadm" ]]; then
      rotation::remote_exec "${node_ip}" "touch /etc/kubernetes/manifests/etcd.yaml" || true
    else
      rotation::remote_exec "${node_ip}" "systemctl restart etcd" || true
    fi

    # 等待健康
    if ! rotation::check_etcd_health "${node_ip}" "${etcd_type}" 60; then
      log::error "Etcd failed to become healthy on ${node}, aborting rotation"
      return 1
    fi

    log::success "Etcd on ${node} restarted and healthy"
  done

  log::success "All etcd nodes restarted successfully"
  return 0
}

# ==============================================================================
# 回滚机制
# ==============================================================================

#######################################
# 回滚到旧证书
# Arguments:
#   $1 - 集群名称
#   $2 - 节点名称
#   $3 - 节点IP
#   $4 - 证书类型 (kubernetes|etcd|all)
#   $5 - 部署类型 (kubeadm|kubexm)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::rollback() {
  local cluster_name="$1"
  local node_name="$2"
  local node_ip="$3"
  local cert_type="${4:-$(defaults::get_cert_type)}"
  local deploy_type="${5:-$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)}"

  local base_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${node_name}"
  local old_dir="${base_dir}/${ROTATION_OLD_DIR}"

  log::warn "Rolling back certificates on ${node_name} (${node_ip})..."

  if [[ "${cert_type}" == "kubernetes" ]] || [[ "${cert_type}" == "all" ]]; then
    log::info "  Restoring Kubernetes certificates..."
    rotation::remote_copy_file "${node_ip}" "${old_dir}/kubernetes/pki/*" "/etc/kubernetes/pki/" || true
    
    log::info "  Restoring kubeconfig files..."
    for conf in "${old_dir}/kubernetes/kubeconfig"/*.conf; do
      if [[ -f "${conf}" ]]; then
        local conf_name
        conf_name=$(basename "${conf}")
        rotation::remote_copy_file "${node_ip}" "${conf}" "/etc/kubernetes/${conf_name}"
      fi
    done
  fi

  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    local etcd_target
    etcd_target="$(rotation::resolve_etcd_cert_dir)"
    log::info "  Restoring etcd certificates..."
    rotation::remote_copy_file "${node_ip}" "${old_dir}/etcd/*" "${etcd_target}/" || true
  fi

  # 重启组件
  rotation::restart_components "${node_ip}" "${cert_type}" "${deploy_type}"

  log::success "Rollback completed on ${node_name}"
  return 0
}

# ==============================================================================
# ConfigMap 更新
# ==============================================================================

#######################################
# 更新 kube-proxy ConfigMap (kubeadm模式)
# Arguments:
#   $1 - kubeconfig 路径
#   $2 - 新 CA 证书路径
# Returns:
#   0 成功, 1 失败
#######################################
rotation::update_kube_proxy_configmap() {
  local kubeconfig="$1"
  local new_ca="$2"

  log::info "Updating kube-proxy ConfigMap..."

  if [[ ! -f "${kubeconfig}" ]]; then
    log::warn "Kubeconfig not found, skipping kube-proxy ConfigMap update"
    return 0
  fi

  # 滚动重启 kube-proxy DaemonSet
  if kubectl --kubeconfig="${kubeconfig}" rollout restart daemonset/kube-proxy -n kube-system >/dev/null 2>&1; then
    log::success "kube-proxy DaemonSet restarted"
    return 0
  else
    log::warn "Failed to restart kube-proxy DaemonSet"
    return 1
  fi
}

#######################################
# 更新 cluster-info ConfigMap
# Arguments:
#   $1 - kubeconfig 路径
#   $2 - 新 CA 证书路径
# Returns:
#   0 成功, 1 失败
#######################################
rotation::update_cluster_info() {
  local kubeconfig="$1"
  local new_ca="$2"

  log::info "Updating cluster-info ConfigMap..."

  if [[ ! -f "${kubeconfig}" ]] || [[ ! -f "${new_ca}" ]]; then
    log::warn "Kubeconfig or CA not found, skipping cluster-info update"
    return 0
  fi

  local ca_data
  ca_data=$(base64 -w 0 "${new_ca}")

  # 获取当前 cluster-info
  local current_data
  current_data=$(kubectl --kubeconfig="${kubeconfig}" get configmap cluster-info -n kube-public -o jsonpath='{.data.kubeconfig}' 2>/dev/null || echo "")

  if [[ -z "${current_data}" ]]; then
    log::warn "cluster-info ConfigMap not found, skipping"
    return 0
  fi

  log::success "cluster-info ConfigMap update noted (manual update may be required)"
  return 0
}

#######################################
# 阶段确认提示
# Arguments:
#   $1 - 阶段名称
#   $2 - 是否需要确认 (true|false)
# Returns:
#   0 继续, 1 中止
#######################################
rotation::confirm_phase() {
  local phase_name="$1"
  local need_confirm="${2:-false}"

  if [[ "${need_confirm}" != "true" ]]; then
    return 0
  fi

  log::warn "=== ${phase_name} 即将执行 ==="
  log::warn "请确认是否继续? [y/N]"
  
  read -r -t 300 response || response="n"
  
  if [[ "${response}" =~ ^[Yy]$ ]]; then
    log::info "用户确认继续执行"
    return 0
  else
    log::error "用户取消执行"
    return 1
  fi
}

# ==============================================================================
# Phase 1: 拉取旧证书
# ==============================================================================

#######################################
# 从节点拉取旧证书到本地
# Arguments:
#   $1 - 集群名称
#   $2 - 节点名称
#   $3 - 节点IP
#   $4 - 证书类型 (kubernetes|etcd|all)
#   $5 - 部署类型 (kubeadm|kubexm)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::pull_old_certs() {
  local cluster_name="$1"
  local node_name="$2"
  local node_ip="$3"
  local cert_type="${4:-$(defaults::get_cert_type)}"
  local deploy_type="${5:-$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)}"
  local etcd_type
  etcd_type="$(rotation::get_etcd_type)"

  local base_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${node_name}/${ROTATION_OLD_DIR}"
  
  log::info "Pulling old certificates from ${node_name} (${node_ip})..."

  mkdir -p "${base_dir}/kubernetes/pki"
  mkdir -p "${base_dir}/kubernetes/kubeconfig"

  # 拉取 Kubernetes 证书
  if [[ "${cert_type}" == "kubernetes" ]] || [[ "${cert_type}" == "all" ]]; then
    log::info "  Pulling Kubernetes certificates..."
    
    # PKI 证书
    rotation::remote_copy_from "${node_ip}" "/etc/kubernetes/pki/*.crt" "${base_dir}/kubernetes/pki/" || true
    rotation::remote_copy_from "${node_ip}" "/etc/kubernetes/pki/*.key" "${base_dir}/kubernetes/pki/" || true
    rotation::remote_copy_from "${node_ip}" "/etc/kubernetes/pki/*.pub" "${base_dir}/kubernetes/pki/" || true
    
    # front-proxy 证书
    rotation::remote_copy_from "${node_ip}" "/etc/kubernetes/pki/front-proxy-*" "${base_dir}/kubernetes/pki/" || true
    
    # kubeconfig 文件
    rotation::remote_copy_from "${node_ip}" "/etc/kubernetes/*.conf" "${base_dir}/kubernetes/kubeconfig/" || true
    
    # kubeadm模式: 备份 manifests
    if [[ "${deploy_type}" == "kubeadm" ]]; then
      log::info "  Backing up static pod manifests..."
      mkdir -p "${base_dir}/manifests"
      rotation::remote_copy_from "${node_ip}" "/etc/kubernetes/manifests/*.yaml" "${base_dir}/manifests/" || true
    fi
    
    log::success "  Kubernetes certificates pulled"
  fi

  # 拉取 etcd 证书
  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    log::info "  Pulling etcd certificates..."
    
    mkdir -p "${base_dir}/etcd"
    
    if [[ "${etcd_type}" == "kubeadm" ]]; then
      # kubeadm: etcd 证书在 /etc/kubernetes/pki/etcd/
      rotation::remote_copy_from "${node_ip}" "/etc/kubernetes/pki/etcd/*.crt" "${base_dir}/etcd/" || true
      rotation::remote_copy_from "${node_ip}" "/etc/kubernetes/pki/etcd/*.key" "${base_dir}/etcd/" || true
    else
      # kubexm: etcd 证书在 /etc/etcd/ssl/
      rotation::remote_copy_from "${node_ip}" "/etc/etcd/ssl/*.crt" "${base_dir}/etcd/" || true
      rotation::remote_copy_from "${node_ip}" "/etc/etcd/ssl/*.key" "${base_dir}/etcd/" || true
    fi
    
    log::success "  etcd certificates pulled"
  fi

  log::success "Old certificates saved to: ${base_dir}"
  return 0
}

# ==============================================================================
# Phase 2: 生成新证书
# ==============================================================================

#######################################
# 生成新证书
# Arguments:
#   $1 - 集群名称
#   $2 - 节点名称
#   $3 - 证书类型 (kubernetes|etcd|all)
#   $4 - API Server 地址
#   $5 - 集群域名
# Returns:
#   0 成功, 1 失败
#######################################
rotation::generate_new_certs() {
  local cluster_name="$1"
  local node_name="$2"
  local cert_type="${3:-$(defaults::get_cert_type)}"
  local api_server="${4:-}"
  local cluster_domain="${5:-$(defaults::get_cluster_domain)}"

  local base_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${node_name}/${ROTATION_NEW_DIR}"
  
  log::info "Generating new certificates for ${node_name}..."

  # 生成 Kubernetes 证书
  if [[ "${cert_type}" == "kubernetes" ]] || [[ "${cert_type}" == "all" ]]; then
    local k8s_pki_dir="${base_dir}/kubernetes/pki"
    local old_pki_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${node_name}/${ROTATION_OLD_DIR}/kubernetes/pki"
    mkdir -p "${k8s_pki_dir}"
    
    log::info "  Generating Kubernetes CA..."
    pki::generate_ca "${k8s_pki_dir}"
    
    log::info "  Generating Kubernetes component certificates..."
    pki::apiserver::generate_all "${k8s_pki_dir}" "${cluster_domain}" "${api_server}"
    pki::front_proxy::generate_all "${k8s_pki_dir}"
    
    # SA 密钥不轮转 - 复制旧的 SA 密钥
    if [[ -f "${old_pki_dir}/sa.key" ]] && [[ -f "${old_pki_dir}/sa.pub" ]]; then
      log::info "  Copying SA keys (not rotating)..."
      cp "${old_pki_dir}/sa.key" "${k8s_pki_dir}/sa.key"
      cp "${old_pki_dir}/sa.pub" "${k8s_pki_dir}/sa.pub"
    else
      log::warn "  Old SA keys not found, generating new ones (may cause Pod disruption)..."
      pki::sa::generate_keypair "${k8s_pki_dir}"
    fi
    
    log::success "  Kubernetes certificates generated"
  fi

  # 生成 etcd 证书
  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    local etcd_dir="${base_dir}/etcd"
    mkdir -p "${etcd_dir}"
    
    log::info "  Generating etcd certificates..."
    
    # 获取 etcd 节点列表
    local etcd_nodes
    etcd_nodes=$(config::get_role_members "etcd" 2>/dev/null || echo "${node_name}")
    
    pki::etcd::generate_all "${etcd_dir}" "${base_dir}/kubernetes/pki" "${etcd_nodes}"
    
    log::success "  etcd certificates generated"
  fi

  log::success "New certificates saved to: ${base_dir}"
  return 0
}

# ==============================================================================
# Phase 3: 创建 Bundle CA
# ==============================================================================

#######################################
# 创建 Bundle CA (合并旧CA和新CA)
# Arguments:
#   $1 - 集群名称
#   $2 - 节点名称
#   $3 - 证书类型 (kubernetes|etcd|all)
#   $4 - API Server 地址
# Returns:
#   0 成功, 1 失败
#######################################
rotation::create_bundle_ca() {
  local cluster_name="$1"
  local node_name="$2"
  local cert_type="${3:-$(defaults::get_cert_type)}"
  local api_server="${4:-}"

  local base_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${node_name}"
  local old_dir="${base_dir}/${ROTATION_OLD_DIR}"
  local new_dir="${base_dir}/${ROTATION_NEW_DIR}"
  local bundle_dir="${base_dir}/${ROTATION_BUNDLE_DIR}"
  
  log::info "Creating bundle CA for ${node_name}..."

  # Kubernetes bundle
  if [[ "${cert_type}" == "kubernetes" ]] || [[ "${cert_type}" == "all" ]]; then
    local bundle_k8s_dir="${bundle_dir}/kubernetes/pki"
    mkdir -p "${bundle_k8s_dir}"
    
    log::info "  Creating Kubernetes CA bundle..."
    
    # 合并 CA 证书 (旧CA在前，新CA在后)
    if [[ -f "${old_dir}/kubernetes/pki/ca.crt" ]] && [[ -f "${new_dir}/kubernetes/pki/ca.crt" ]]; then
      cat "${old_dir}/kubernetes/pki/ca.crt" "${new_dir}/kubernetes/pki/ca.crt" > "${bundle_k8s_dir}/ca.crt"
      log::info "    ca.crt bundle created"
    fi
    
    # 合并 front-proxy CA
    if [[ -f "${old_dir}/kubernetes/pki/front-proxy-ca.crt" ]] && [[ -f "${new_dir}/kubernetes/pki/front-proxy-ca.crt" ]]; then
      cat "${old_dir}/kubernetes/pki/front-proxy-ca.crt" "${new_dir}/kubernetes/pki/front-proxy-ca.crt" > "${bundle_k8s_dir}/front-proxy-ca.crt"
      log::info "    front-proxy-ca.crt bundle created"
    fi
    
    # 复制新CA的密钥 (不合并密钥)
    cp "${new_dir}/kubernetes/pki/ca.key" "${bundle_k8s_dir}/ca.key" 2>/dev/null || true
    
    # 生成基于 bundle CA 的 kubeconfig
    log::info "  Generating kubeconfigs with bundle CA..."
    mkdir -p "${bundle_dir}/kubernetes/kubeconfig"
    
    kubeconfig::generate_all \
      "${bundle_dir}/kubernetes/kubeconfig" \
      "${api_server}" \
      "${new_dir}/kubernetes/pki" \
      "${node_name}"
    
    # 替换 kubeconfig 中的 CA 为 bundle CA
    for conf in "${bundle_dir}/kubernetes/kubeconfig"/*.conf; do
      if [[ -f "${conf}" ]]; then
        local bundle_ca_data
        bundle_ca_data=$(base64 -w 0 "${bundle_k8s_dir}/ca.crt")
        sed -i "s|certificate-authority-data:.*|certificate-authority-data: ${bundle_ca_data}|g" "${conf}"
      fi
    done
    
    log::success "  Kubernetes bundle created"
  fi

  # etcd bundle
  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    local bundle_etcd_dir="${bundle_dir}/etcd"
    mkdir -p "${bundle_etcd_dir}"
    
    log::info "  Creating etcd CA bundle..."
    
    if [[ -f "${old_dir}/etcd/ca.crt" ]] && [[ -f "${new_dir}/etcd/ca.crt" ]]; then
      cat "${old_dir}/etcd/ca.crt" "${new_dir}/etcd/ca.crt" > "${bundle_etcd_dir}/ca.crt"
      log::info "    etcd ca.crt bundle created"
    fi
    
    log::success "  etcd bundle created"
  fi

  # 验证 bundle CA
  if [[ -f "${bundle_k8s_dir}/ca.crt" ]]; then
    rotation::verify_bundle_ca "${bundle_k8s_dir}/ca.crt" || {
      log::error "Bundle CA verification failed"
      return 1
    }
  fi

  log::success "Bundle CA saved to: ${bundle_dir}"
  return 0
}

# ==============================================================================
# Phase 4-6: 分发证书
# ==============================================================================

#######################################
# 分发证书到节点 (带错误处理和自动回滚)
# Arguments:
#   $1 - 集群名称
#   $2 - 节点名称
#   $3 - 节点IP
#   $4 - 阶段 (bundle|leaf|newca)
#   $5 - 证书类型 (kubernetes|etcd|all)
#   $6 - 部署类型 (kubeadm|kubexm)
#   $7 - 失败时是否自动回滚 (true|false)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::distribute() {
  local cluster_name="$1"
  local node_name="$2"
  local node_ip="$3"
  local phase="$4"
  local cert_type="${5:-$(defaults::get_cert_type)}"
  local deploy_type="${6:-$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)}"
  local auto_rollback="${7:-true}"

  local base_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${node_name}"
  local distribute_failed=false
  
  log::info "Distributing ${phase} certificates to ${node_name} (${node_ip})..."

  case "${phase}" in
    bundle)
      # Phase 4: 分发 bundle CA 和 kubeconfig
      if ! rotation::_distribute_bundle "${base_dir}" "${node_ip}" "${cert_type}" "${deploy_type}"; then
        distribute_failed=true
      fi
      ;;
    leaf)
      # Phase 5: 分发新叶子证书
      if ! rotation::_distribute_leaf "${base_dir}" "${node_ip}" "${cert_type}" "${deploy_type}"; then
        distribute_failed=true
      fi
      ;;
    newca)
      # Phase 6: 分发新根CA
      if ! rotation::_distribute_new_ca "${base_dir}" "${node_ip}" "${cert_type}" "${deploy_type}"; then
        distribute_failed=true
      fi
      ;;
    *)
      log::error "Unknown phase: ${phase}"
      return 1
      ;;
  esac

  # 检查分发结果
  if [[ "${distribute_failed}" == "true" ]]; then
    log::error "Distribution failed for ${node_name}"
    
    if [[ "${auto_rollback}" == "true" ]]; then
      log::warn "Auto-rollback enabled, restoring old certificates..."
      rotation::rollback "${cluster_name}" "${node_name}" "${node_ip}" "${cert_type}" "${deploy_type}"
    fi
    
    return 1
  fi

  # 重启组件
  if ! rotation::restart_components "${node_ip}" "${cert_type}" "${deploy_type}"; then
    log::warn "Component restart had issues on ${node_ip}"
  fi

  log::success "Phase ${phase} completed for ${node_name}"
  return 0
}

#######################################
# 内部函数: 分发 bundle (带错误处理)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::_distribute_bundle() {
  local base_dir="$1"
  local node_ip="$2"
  local cert_type="$3"
  local deploy_type="$4"
  local has_error=false

  local bundle_dir="${base_dir}/${ROTATION_BUNDLE_DIR}"

  if [[ "${cert_type}" == "kubernetes" ]] || [[ "${cert_type}" == "all" ]]; then
    # 分发 bundle CA (关键操作)
    if ! rotation::remote_copy_file "${node_ip}" "${bundle_dir}/kubernetes/pki/ca.crt" "/etc/kubernetes/pki/ca.crt"; then
      log::error "Failed to distribute ca.crt to ${node_ip}"
      has_error=true
    fi
    rotation::remote_copy_file "${node_ip}" "${bundle_dir}/kubernetes/pki/front-proxy-ca.crt" "/etc/kubernetes/pki/front-proxy-ca.crt" || true
    
    # 分发 kubeconfig
    for conf in "${bundle_dir}/kubernetes/kubeconfig"/*.conf; do
      if [[ -f "${conf}" ]]; then
        local conf_name
        conf_name=$(basename "${conf}")
        if ! rotation::remote_copy_file "${node_ip}" "${conf}" "/etc/kubernetes/${conf_name}"; then
          log::error "Failed to distribute ${conf_name} to ${node_ip}"
          has_error=true
        fi
      fi
    done
  fi

  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    local etcd_target
    etcd_target="$(rotation::resolve_etcd_cert_dir)"
    rotation::remote_copy_file "${node_ip}" "${bundle_dir}/etcd/ca.crt" "${etcd_target}/ca.crt" || true
  fi

  [[ "${has_error}" == "false" ]]
}

#######################################
# 内部函数: 分发新叶子证书
#######################################
rotation::_distribute_leaf() {
  local base_dir="$1"
  local node_ip="$2"
  local cert_type="$3"
  local deploy_type="$4"

  local new_dir="${base_dir}/${ROTATION_NEW_DIR}"

  if [[ "${cert_type}" == "kubernetes" ]] || [[ "${cert_type}" == "all" ]]; then
    # 分发所有叶子证书 (非CA)
    for cert_file in "${new_dir}/kubernetes/pki"/*.crt; do
      if [[ -f "${cert_file}" ]]; then
        local cert_name
        cert_name=$(basename "${cert_file}")
        # 跳过 CA 证书
        if [[ "${cert_name}" != "ca.crt" ]] && [[ "${cert_name}" != "front-proxy-ca.crt" ]]; then
          rotation::remote_copy_file "${node_ip}" "${cert_file}" "/etc/kubernetes/pki/${cert_name}"
          # 同时分发对应的密钥
          local key_file="${cert_file%.crt}.key"
          if [[ -f "${key_file}" ]]; then
            rotation::remote_copy_file "${node_ip}" "${key_file}" "/etc/kubernetes/pki/${cert_name%.crt}.key"
          fi
        fi
      fi
    done
  fi

  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    local etcd_target
    etcd_target="$(rotation::resolve_etcd_cert_dir)"
    
    for cert_file in "${new_dir}/etcd"/*.crt; do
      if [[ -f "${cert_file}" ]]; then
        local cert_name
        cert_name=$(basename "${cert_file}")
        if [[ "${cert_name}" != "ca.crt" ]]; then
          rotation::remote_copy_file "${node_ip}" "${cert_file}" "${etcd_target}/${cert_name}"
          local key_file="${cert_file%.crt}.key"
          if [[ -f "${key_file}" ]]; then
            rotation::remote_copy_file "${node_ip}" "${key_file}" "${etcd_target}/${cert_name%.crt}.key"
          fi
        fi
      fi
    done
  fi
}

#######################################
# 内部函数: 分发新根CA
#######################################
rotation::_distribute_new_ca() {
  local base_dir="$1"
  local node_ip="$2"
  local cert_type="$3"
  local deploy_type="$4"

  local new_dir="${base_dir}/${ROTATION_NEW_DIR}"

  if [[ "${cert_type}" == "kubernetes" ]] || [[ "${cert_type}" == "all" ]]; then
    rotation::remote_copy_file "${node_ip}" "${new_dir}/kubernetes/pki/ca.crt" "/etc/kubernetes/pki/ca.crt"
    rotation::remote_copy_file "${node_ip}" "${new_dir}/kubernetes/pki/ca.key" "/etc/kubernetes/pki/ca.key"
    rotation::remote_copy_file "${node_ip}" "${new_dir}/kubernetes/pki/front-proxy-ca.crt" "/etc/kubernetes/pki/front-proxy-ca.crt" || true
    rotation::remote_copy_file "${node_ip}" "${new_dir}/kubernetes/pki/front-proxy-ca.key" "/etc/kubernetes/pki/front-proxy-ca.key" || true
  fi

  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    local etcd_target
    etcd_target="$(rotation::resolve_etcd_cert_dir)"
    rotation::remote_copy_file "${node_ip}" "${new_dir}/etcd/ca.crt" "${etcd_target}/ca.crt" || true
    rotation::remote_copy_file "${node_ip}" "${new_dir}/etcd/ca.key" "${etcd_target}/ca.key" || true
  fi
}

# ==============================================================================
# 组件重启
# ==============================================================================

#######################################
# 重启组件
# Arguments:
#   $1 - 节点IP
#   $2 - 证书类型 (kubernetes|etcd|all)
#   $3 - 部署类型 (kubeadm|kubexm)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::restart_components() {
  local node_ip="$1"
  local cert_type="${2:-$(defaults::get_cert_type)}"
  local deploy_type="${3:-$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)}"
  local etcd_type
  etcd_type="$(rotation::get_etcd_type)"
  local has_error=false

  log::info "Restarting components on ${node_ip}..."

  if [[ "${cert_type}" == "kubernetes" ]] || [[ "${cert_type}" == "all" ]]; then
    if [[ "${deploy_type}" == "kubeadm" ]]; then
      # kubeadm: 通过修改 manifest 触发 Pod 重启
      log::info "  Triggering static pod restart (kubeadm mode)..."
      rotation::remote_exec "${node_ip}" "touch /etc/kubernetes/manifests/kube-apiserver.yaml" || true
      sleep 10
      # 检查apiserver是否启动
      if ! rotation::remote_exec "${node_ip}" "curl -sk https://localhost:6443/healthz" >/dev/null 2>&1; then
        log::warn "  API server may not be healthy on ${node_ip}"
        has_error=true
      fi
      rotation::remote_exec "${node_ip}" "touch /etc/kubernetes/manifests/kube-controller-manager.yaml" || true
      rotation::remote_exec "${node_ip}" "touch /etc/kubernetes/manifests/kube-scheduler.yaml" || true
    else
      # kubexm: 重启 systemd 服务
      log::info "  Restarting systemd services (kubexm mode)..."
      if ! rotation::remote_exec "${node_ip}" "systemctl restart kube-apiserver"; then
        log::error "  Failed to restart kube-apiserver on ${node_ip}"
        has_error=true
      fi
      sleep 10
      rotation::remote_exec "${node_ip}" "systemctl restart kube-controller-manager" || true
      rotation::remote_exec "${node_ip}" "systemctl restart kube-scheduler" || true
    fi
    
    # kubelet 总是 systemd
    if ! rotation::remote_exec "${node_ip}" "systemctl restart kubelet"; then
      log::warn "  Failed to restart kubelet on ${node_ip}"
    fi
    # 等待kubelet恢复
    sleep 5
    if ! rotation::remote_exec "${node_ip}" "systemctl is-active kubelet" >/dev/null 2>&1; then
      log::error "  Kubelet is not running on ${node_ip}"
      has_error=true
    fi
  fi

  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    if [[ "${etcd_type}" == "kubeadm" ]]; then
      rotation::remote_exec "${node_ip}" "touch /etc/kubernetes/manifests/etcd.yaml" || true
    else
      if ! rotation::remote_exec "${node_ip}" "systemctl restart etcd"; then
        log::error "  Failed to restart etcd on ${node_ip}"
        has_error=true
      fi
    fi
  fi

  if [[ "${has_error}" == "true" ]]; then
    log::warn "Some components failed to restart on ${node_ip}, cluster may be unstable"
    return 1
  fi

  log::success "Components restarted on ${node_ip}"
  return 0
}

# ==============================================================================
# 完整轮转流程
# ==============================================================================

#######################################
# 执行完整证书轮转
# Arguments:
#   $1 - 集群名称
#   $2 - 证书类型 (kubernetes|etcd|all)
#   $3 - 部署类型 (kubeadm|kubexm)
#   $4 - 是否需要确认 (true|false)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::rotate_all() {
  local cluster_name="$1"
  local cert_type="${2:-$(defaults::get_cert_type)}"
  local deploy_type="${3:-$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)}"
  local need_confirm="${4:-false}"

  log::info "Starting certificate rotation for cluster: ${cluster_name}"
  log::info "Certificate type: ${cert_type}"
  log::info "Deploy type: ${deploy_type}"

  # 获取 API Server 地址
  local api_server
  api_server=$(config::get_apiserver_address 2>/dev/null || echo "")
  if [[ -z "${api_server}" ]]; then
    api_server=$(config::get_loadbalancer_vip 2>/dev/null || echo "")
  fi
  if [[ -n "${api_server}" ]] && [[ ! "${api_server}" =~ ^https:// ]]; then
    api_server="https://${api_server}:6443"
  fi
  log::info "API Server: ${api_server}"

  # 获取节点列表
  local master_nodes worker_nodes etcd_nodes
  master_nodes=$(config::get_role_members "master" 2>/dev/null || echo "")
  worker_nodes=$(config::get_role_members "worker" 2>/dev/null || echo "")
  etcd_nodes=$(config::get_role_members "etcd" 2>/dev/null || echo "")
  local etcd_type
  etcd_type="$(rotation::get_etcd_type)"
  if [[ "${etcd_type}" == "exists" ]]; then
    etcd_nodes=$(config::get_etcd_external_endpoints_hosts 2>/dev/null || echo "")
  fi
  if [[ ( "${cert_type}" == "etcd" || "${cert_type}" == "all" ) && -z "${etcd_nodes}" ]]; then
    log::error "No etcd role members found for etcd certificate rotation"
    return 1
  fi

  # =========================================================================
  # Phase 1: 准备证书
  # =========================================================================
  rotation::confirm_phase "Phase 1: 准备证书" "${need_confirm}" || return 1
  log::info "=== Phase 1: Prepare certificates ==="
  
  # Master 节点
  for node_name in ${master_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
    
    log::info "Preparing certificates for master: ${node_name}"
    rotation::pull_old_certs "${cluster_name}" "${node_name}" "${node_ip}" "${cert_type}" "${deploy_type}"
    rotation::generate_new_certs "${cluster_name}" "${node_name}" "${cert_type}" "${api_server}" ""
    rotation::create_bundle_ca "${cluster_name}" "${node_name}" "${cert_type}" "${api_server}"
  done

  # Worker 节点 (只需要 kubelet)
  for node_name in ${worker_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
    
    log::info "Preparing certificates for worker: ${node_name}"
    rotation::pull_old_certs "${cluster_name}" "${node_name}" "${node_ip}" "kubernetes" "${deploy_type}"
    rotation::generate_new_certs "${cluster_name}" "${node_name}" "kubernetes" "${api_server}" ""
    rotation::create_bundle_ca "${cluster_name}" "${node_name}" "kubernetes" "${api_server}"
  done

  # =========================================================================
  # Phase 2: 分发 Bundle CA
  # =========================================================================
  rotation::confirm_phase "Phase 2: 分发 Bundle CA" "${need_confirm}" || return 1
  log::info "=== Phase 2: Distribute bundle CA ==="
  
  # etcd 节点先分发并健康检查
  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    for node_name in ${etcd_nodes}; do
      local node_ip
      node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
      rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "bundle" "etcd" "${deploy_type}"
    done
    
    # etcd 健康检查
    rotation::restart_etcd_with_health_check "${etcd_nodes}" "${etcd_type}" || {
      log::error "Etcd health check failed after bundle distribution"
      return 1
    }
  fi

  # Master 节点
  for node_name in ${master_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
    rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "bundle" "kubernetes" "${deploy_type}"
    sleep 10
  done

  # Worker 节点
  for node_name in ${worker_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
    rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "bundle" "kubernetes" "${deploy_type}"
    sleep 5
  done

  # =========================================================================
  # Phase 3: 分发新叶子证书
  # =========================================================================
  rotation::confirm_phase "Phase 3: 分发新叶子证书" "${need_confirm}" || return 1
  log::info "=== Phase 3: Distribute leaf certificates ==="
  
  # etcd 节点
  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    for node_name in ${etcd_nodes}; do
      local node_ip
      node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
      rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "leaf" "etcd" "${deploy_type}"
    done
    rotation::restart_etcd_with_health_check "${etcd_nodes}" "${etcd_type}" || {
      log::error "Etcd health check failed after leaf distribution"
      return 1
    }
  fi

  # Master 节点
  for node_name in ${master_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
    rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "leaf" "kubernetes" "${deploy_type}"
    sleep 10
  done

  # Worker 节点
  for node_name in ${worker_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
    rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "leaf" "kubernetes" "${deploy_type}"
    sleep 5
  done

  # =========================================================================
  # Phase 4: 分发新根 CA
  # =========================================================================
  rotation::confirm_phase "Phase 4: 分发新根 CA" "${need_confirm}" || return 1
  log::info "=== Phase 4: Distribute new CA ==="
  
  # etcd 节点
  if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
    for node_name in ${etcd_nodes}; do
      local node_ip
      node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
      rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "newca" "etcd" "${deploy_type}"
    done
    rotation::restart_etcd_with_health_check "${etcd_nodes}" "${etcd_type}" || {
      log::error "Etcd health check failed after new CA distribution"
      return 1
    }
  fi

  # Master 节点
  for node_name in ${master_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
    rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "newca" "kubernetes" "${deploy_type}"
    sleep 10
  done

  # Worker 节点
  for node_name in ${worker_nodes}; do
    local node_ip
    node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
    rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "newca" "kubernetes" "${deploy_type}"
    sleep 5
  done

  # =========================================================================
  # Phase 5: 更新 ConfigMap
  # =========================================================================
  rotation::confirm_phase "Phase 5: 更新 ConfigMap" "${need_confirm}" || return 1
  log::info "=== Phase 5: Update ConfigMaps ==="
  
  local first_master
  first_master=$(echo "${master_nodes}" | awk '{print $1}')
  local first_master_ip
  first_master_ip=$(config::get_host_address "${first_master}" 2>/dev/null || echo "${first_master}")
  local new_ca="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${first_master}/${ROTATION_NEW_DIR}/kubernetes/pki/ca.crt"
  local admin_conf="/etc/kubernetes/admin.conf"

  if [[ "${deploy_type}" == "kubeadm" ]]; then
    # kubeadm 模式更新 ConfigMap
    rotation::update_kube_proxy_configmap "${admin_conf}" "${new_ca}"
    rotation::update_cluster_info "${admin_conf}" "${new_ca}"
  else
    # kubexm 模式重启 kube-proxy
    for node_name in ${master_nodes} ${worker_nodes}; do
      local node_ip
      node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
      rotation::remote_exec "${node_ip}" "systemctl restart kube-proxy" || true
    done
  fi

  log::success "Certificate rotation completed for cluster: ${cluster_name}"
  return 0
}

#######################################
# 执行单个阶段证书轮转
# Arguments:
#   $1 - 集群名称
#   $2 - 证书类型 (kubernetes|etcd|all)
#   $3 - 部署类型 (kubeadm|kubexm)
#   $4 - 阶段 (1|2|3|4|5)
#   $5 - 是否需要确认 (true|false)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::rotate_phase() {
  local cluster_name="$1"
  local cert_type="${2:-$(defaults::get_cert_type)}"
  local deploy_type="${3:-$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)}"
  local phase="${4:-}"
  local need_confirm="${5:-false}"

  if [[ -z "${phase}" ]]; then
    log::error "Phase number is required"
    return 1
  fi

  log::info "Starting certificate rotation phase ${phase} for cluster: ${cluster_name}"
  log::info "Certificate type: ${cert_type}"
  log::info "Deploy type: ${deploy_type}"

  # 获取 API Server 地址
  local api_server
  api_server=$(config::get_apiserver_address 2>/dev/null || echo "")
  if [[ -z "${api_server}" ]]; then
    api_server=$(config::get_etcd_external_endpoints 2>/dev/null || echo "")
  fi
  if [[ -n "${api_server}" ]] && [[ ! "${api_server}" =~ ^https:// ]]; then
    api_server="https://${api_server}:6443"
  fi
  log::info "API Server: ${api_server}"

  # 获取节点列表
  local master_nodes worker_nodes etcd_nodes
  master_nodes=$(config::get_role_members "master" 2>/dev/null || echo "")
  worker_nodes=$(config::get_role_members "worker" 2>/dev/null || echo "")
  etcd_nodes=$(config::get_role_members "etcd" 2>/dev/null || echo "")
  local etcd_type
  etcd_type="$(rotation::get_etcd_type)"
  if [[ "${etcd_type}" == "exists" ]]; then
    etcd_nodes=$(config::get_etcd_external_endpoints_hosts 2>/dev/null || echo "")
  fi
  if [[ ( "${cert_type}" == "etcd" || "${cert_type}" == "all" ) && -z "${etcd_nodes}" ]]; then
    log::error "No etcd role members found for etcd certificate rotation"
    return 1
  fi

  case "${phase}" in
    1)
      # Phase 1: 准备证书
      rotation::confirm_phase "Phase 1: 准备证书" "${need_confirm}" || return 1
      log::info "=== Phase 1: Prepare certificates ==="

      for node_name in ${master_nodes}; do
        local node_ip
        node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
        log::info "Preparing certificates for master: ${node_name}"
        rotation::pull_old_certs "${cluster_name}" "${node_name}" "${node_ip}" "${cert_type}" "${deploy_type}"
        rotation::generate_new_certs "${cluster_name}" "${node_name}" "${cert_type}" "${api_server}" ""
        rotation::create_bundle_ca "${cluster_name}" "${node_name}" "${cert_type}" "${api_server}"
      done

      for node_name in ${worker_nodes}; do
        local node_ip
        node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
        log::info "Preparing certificates for worker: ${node_name}"
        rotation::pull_old_certs "${cluster_name}" "${node_name}" "${node_ip}" "kubernetes" "${deploy_type}"
        rotation::generate_new_certs "${cluster_name}" "${node_name}" "kubernetes" "${api_server}" ""
        rotation::create_bundle_ca "${cluster_name}" "${node_name}" "kubernetes" "${api_server}"
      done

      log::success "Phase 1 completed: certificates prepared"
      ;;

    2)
      # Phase 2: 分发 Bundle CA
      rotation::confirm_phase "Phase 2: 分发 Bundle CA" "${need_confirm}" || return 1
      log::info "=== Phase 2: Distribute bundle CA ==="

      if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
        for node_name in ${etcd_nodes}; do
          local node_ip
          node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
          rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "bundle" "etcd" "${deploy_type}"
        done
        rotation::restart_etcd_with_health_check "${etcd_nodes}" "${etcd_type}" || {
          log::error "Etcd health check failed after bundle distribution"
          return 1
        }
      fi

      for node_name in ${master_nodes}; do
        local node_ip
        node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
        rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "bundle" "kubernetes" "${deploy_type}"
        sleep 10
      done

      for node_name in ${worker_nodes}; do
        local node_ip
        node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
        rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "bundle" "kubernetes" "${deploy_type}"
        sleep 5
      done

      log::success "Phase 2 completed: bundle CA distributed"
      ;;

    3)
      # Phase 3: 分发新叶子证书
      rotation::confirm_phase "Phase 3: 分发新叶子证书" "${need_confirm}" || return 1
      log::info "=== Phase 3: Distribute leaf certificates ==="

      if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
        for node_name in ${etcd_nodes}; do
          local node_ip
          node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
          rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "leaf" "etcd" "${deploy_type}"
        done
        rotation::restart_etcd_with_health_check "${etcd_nodes}" "${etcd_type}" || {
          log::error "Etcd health check failed after leaf distribution"
          return 1
        }
      fi

      for node_name in ${master_nodes}; do
        local node_ip
        node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
        rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "leaf" "kubernetes" "${deploy_type}"
        sleep 10
      done

      for node_name in ${worker_nodes}; do
        local node_ip
        node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
        rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "leaf" "kubernetes" "${deploy_type}"
        sleep 5
      done

      log::success "Phase 3 completed: leaf certificates distributed"
      ;;

    4)
      # Phase 4: 分发新根 CA
      rotation::confirm_phase "Phase 4: 分发新根 CA" "${need_confirm}" || return 1
      log::info "=== Phase 4: Distribute new CA ==="

      if [[ "${cert_type}" == "etcd" ]] || [[ "${cert_type}" == "all" ]]; then
        for node_name in ${etcd_nodes}; do
          local node_ip
          node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
          rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "newca" "etcd" "${deploy_type}"
        done
        rotation::restart_etcd_with_health_check "${etcd_nodes}" "${etcd_type}" || {
          log::error "Etcd health check failed after new CA distribution"
          return 1
        }
      fi

      for node_name in ${master_nodes}; do
        local node_ip
        node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
        rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "newca" "kubernetes" "${deploy_type}"
        sleep 10
      done

      for node_name in ${worker_nodes}; do
        local node_ip
        node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
        rotation::distribute "${cluster_name}" "${node_name}" "${node_ip}" "newca" "kubernetes" "${deploy_type}"
        sleep 5
      done

      log::success "Phase 4 completed: new CA distributed"
      ;;

    5)
      # Phase 5: 更新 ConfigMap
      rotation::confirm_phase "Phase 5: 更新 ConfigMap" "${need_confirm}" || return 1
      log::info "=== Phase 5: Update ConfigMaps ==="

      local first_master
      first_master=$(echo "${master_nodes}" | awk '{print $1}')
      local first_master_ip
      first_master_ip=$(config::get_host_address "${first_master}" 2>/dev/null || echo "${first_master}")
      local new_ca="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs/${first_master}/${ROTATION_NEW_DIR}/kubernetes/pki/ca.crt"
      local admin_conf="/etc/kubernetes/admin.conf"

      if [[ "${deploy_type}" == "kubeadm" ]]; then
        rotation::update_kube_proxy_configmap "${admin_conf}" "${new_ca}"
        rotation::update_cluster_info "${admin_conf}" "${new_ca}"
      else
        for node_name in ${master_nodes} ${worker_nodes}; do
          local node_ip
          node_ip=$(config::get_host_address "${node_name}" 2>/dev/null || echo "${node_name}")
          rotation::remote_exec "${node_ip}" "systemctl restart kube-proxy" || true
        done
      fi

      log::success "Phase 5 completed: ConfigMaps updated"
      ;;

    *)
      log::error "Unknown phase: ${phase}. Valid phases: 1, 2, 3, 4, 5"
      return 1
      ;;
  esac

  return 0
}

#######################################
# 设置证书自动续期 (基于 autoRenewCerts 配置)
# Arguments:
#   $1 - 节点IP
#   $2 - 集群名称
#   $3 - 部署类型 (kubeadm|kubexm)
# Returns:
#   0 成功, 1 失败
#######################################
rotation::setup_auto_renew() {
  local node_ip="$1"
  local cluster_name="$2"
  local deploy_type="${3:-$(config::get_kubernetes_type 2>/dev/null || defaults::get_kubernetes_type)}"

  # 检查是否启用自动续期
  local auto_renew auto_renew_enabled days_before renew_schedule
  auto_renew=$(config::get "spec.kubernetes.autoRenewCerts" "false" 2>/dev/null || echo "false")
  auto_renew_enabled=$(config::get "spec.certificates.auto_renew.enabled" "false" 2>/dev/null || echo "false")
  days_before=$(config::get "spec.certificates.auto_renew.days_before_expiry" "30" 2>/dev/null || echo "30")
  renew_schedule=$(config::get "spec.certificates.auto_renew.schedule" "daily" 2>/dev/null || echo "daily")

  if [[ "${auto_renew}" != "true" ]] && [[ "${auto_renew_enabled}" != "true" ]]; then
    log::info "Auto certificate renewal is disabled"
    return 0
  fi

  log::info "Setting up auto certificate renewal on ${node_ip} (systemd timer)..."
  log::info "  Days before expiry: ${days_before}"
  log::info "  Check schedule: ${renew_schedule}"

  # 确定证书目录
  local pki_dir="/etc/kubernetes/pki"
  if [[ "${deploy_type}" == "kubexm" ]]; then
    pki_dir="/etc/kubernetes/pki"  # kubexm 模式仍然使用相同路径
  fi

  # 创建证书检查续期脚本
  local check_script="/usr/local/bin/kubexm-cert-check.sh"
  local script_content="#!/bin/bash
set -e

DAYS_BEFORE=\${CERT_RENEW_DAYS_BEFORE:-${days_before}}
CERT_DIR=\"\${PKI_DIR:-${pki_dir}}\"
LOG_FILE=\"/var/log/kubexm-cert-renew.log\"
CLUSTER_NAME=\"\${KUBEXM_CLUSTER_NAME:-${cluster_name}}\"

log_msg() {
  echo \"\$(date '+%Y-%m-%d %H:%M:%S'): \$1\" | tee -a \${LOG_FILE}
}

check_cert_expiry() {
  local cert=\$1
  local expiry_date
  expiry_date=\$(openssl x509 -enddate -noout -in \"\${cert}\" 2>/dev/null | cut -d= -f2)
  if [[ -z \"\${expiry_date}\" ]]; then
    echo \"-1\"
    return
  fi
  local expiry_epoch
  expiry_epoch=\$(date -d \"\${expiry_date}\" +%s 2>/dev/null || echo \"0\")
  local current_epoch
  current_epoch=\$(date +%s)
  local days_left
  days_left=\$(( (expiry_epoch - current_epoch) / 86400 ))
  echo \${days_left}
}

log_msg \"Starting certificate expiry check for cluster \${CLUSTER_NAME}\"

needs_renewal=false
certs_to_renew=\"\"

# 检查所有叶子证书
for cert in \${CERT_DIR}/*.crt \${CERT_DIR}/etcd/*.crt; do
  if [[ -f \"\${cert}\" ]]; then
    cert_name=\$(basename \"\${cert}\")
    # 跳过 CA 证书
    if [[ \"\${cert_name}\" == \"ca.crt\" ]] || [[ \"\${cert_name}\" == \"front-proxy-ca.crt\" ]] || [[ \"\${cert_name}\" == \"etcd-ca.crt\" ]]; then
      continue
    fi
    days_left=\$(check_cert_expiry \"\${cert}\")
    if [[ \${days_left} -lt \${DAYS_BEFORE} ]]; then
      log_msg \"WARNING: Certificate \${cert} expires in \${days_left} days\"
      needs_renewal=true
      certs_to_renew=\"\${certs_to_renew} \${cert_name}\"
    else
      log_msg \"OK: Certificate \${cert_name} expires in \${days_left} days\"
    fi
  fi
done

if [[ \"\${needs_renewal}\" == \"true\" ]]; then
  log_msg \"Starting certificate renewal for: \${certs_to_renew}\"
  
  # kubeadm 模式使用 kubeadm certs renew
  if command -v kubeadm &>/dev/null; then
    log_msg \"Using kubeadm certs renew all...\"
    if kubeadm certs renew all >> \${LOG_FILE} 2>&1; then
      log_msg \"Certificate renewal successful\"
      log_msg \"Restarting kubelet...\"
      systemctl restart kubelet
      log_msg \"Kubelet restarted\"
    else
      log_msg \"ERROR: Certificate renewal failed\"
      exit 1
    fi
  else
    log_msg \"ERROR: kubeadm not found, manual renewal required\"
    exit 1
  fi
else
  log_msg \"All certificates are valid, no renewal needed\"
fi
"

  rotation::remote_exec "${node_ip}" "cat > ${check_script} << 'SCRIPT_EOF'
${script_content}
SCRIPT_EOF"
  rotation::remote_exec "${node_ip}" "chmod +x ${check_script}"

  # 渲染并部署 systemd service (使用类型特定的模板)
  local temp_dir
  temp_dir=$(mktemp -d)
  trap 'rm -rf "${temp_dir}"' RETURN
  
  # 设置模板变量
  export CERT_RENEW_DAYS_BEFORE="${days_before}"
  export PKI_DIR="${pki_dir}"
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  
  # 根据部署类型选择模板
  local service_template
  if [[ "${deploy_type}" == "kubeadm" ]]; then
    service_template="${KUBEXM_SCRIPT_ROOT}/templates/systemd/kubexm-cert-renew-kubeadm.service.tmpl"
  else
    service_template="${KUBEXM_SCRIPT_ROOT}/templates/systemd/kubexm-cert-renew-kubexm.service.tmpl"
  fi
  local service_output="${temp_dir}/kubexm-cert-renew.service"
  
  if [[ -f "${service_template}" ]]; then
    log::info "Using template for ${deploy_type}: ${service_template}"
    envsubst < "${service_template}" > "${service_output}"
    rotation::remote_copy_file "${service_output}" "${node_ip}" "/etc/systemd/system/kubexm-cert-renew.service"
  else
    # 回退到通用模板
    local fallback_template="${KUBEXM_SCRIPT_ROOT}/templates/systemd/kubexm-cert-renew.service.tmpl"
    if [[ -f "${fallback_template}" ]]; then
      log::warn "Type-specific template not found, using generic template"
      envsubst < "${fallback_template}" > "${service_output}"
      rotation::remote_copy_file "${service_output}" "${node_ip}" "/etc/systemd/system/kubexm-cert-renew.service"
    else
      # 回退到内联方式
      log::warn "No template found, using inline service definition"
      rotation::remote_exec "${node_ip}" "cat > /etc/systemd/system/kubexm-cert-renew.service << 'EOF'
[Unit]
Description=Kubernetes Certificate Renewal Check
After=kubelet.service

[Service]
Type=oneshot
Environment=CERT_RENEW_DAYS_BEFORE=${days_before}
Environment=PKI_DIR=${pki_dir}
Environment=KUBEXM_CLUSTER_NAME=${cluster_name}
ExecStart=${check_script}
StandardOutput=journal
StandardError=journal
EOF"
    fi
  fi

  # 渲染并部署 systemd timer (使用模板)
  export CERT_RENEW_SCHEDULE="${renew_schedule}"
  
  local timer_template="${KUBEXM_SCRIPT_ROOT}/templates/systemd/kubexm-cert-renew.timer.tmpl"
  local timer_output="${temp_dir}/kubexm-cert-renew.timer"
  
  if [[ -f "${timer_template}" ]]; then
    envsubst < "${timer_template}" > "${timer_output}"
    rotation::remote_copy_file "${timer_output}" "${node_ip}" "/etc/systemd/system/kubexm-cert-renew.timer"
  else
    # 回退到内联方式
    log::warn "Template not found: ${timer_template}, using inline"
    rotation::remote_exec "${node_ip}" "cat > /etc/systemd/system/kubexm-cert-renew.timer << 'EOF'
[Unit]
Description=Kubernetes Certificate Renewal Timer
Requires=kubexm-cert-renew.service

[Timer]
OnCalendar=${renew_schedule}
Persistent=true
RandomizedDelaySec=600

[Install]
WantedBy=timers.target
EOF"
  fi

  # 清理临时目录
  rm -rf "${temp_dir}"

  # 启用 timer
  rotation::remote_exec "${node_ip}" "systemctl daemon-reload && systemctl enable kubexm-cert-renew.timer && systemctl start kubexm-cert-renew.timer"

  log::success "Auto certificate renewal configured with systemd timer (schedule: ${renew_schedule})"
  return 0
}

# 导出函数
export -f rotation::verify_cert_chain
export -f rotation::verify_bundle_ca
export -f rotation::check_etcd_health
export -f rotation::restart_etcd_with_health_check
export -f rotation::rollback
export -f rotation::update_kube_proxy_configmap
export -f rotation::update_cluster_info
export -f rotation::confirm_phase
export -f rotation::pull_old_certs
export -f rotation::generate_new_certs
export -f rotation::create_bundle_ca
export -f rotation::distribute
export -f rotation::restart_components
export -f rotation::rotate_all
export -f rotation::rotate_phase
export -f rotation::setup_auto_renew
