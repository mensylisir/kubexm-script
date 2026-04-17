#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Kubeconfig Generator
# ==============================================================================
# 生成各种 Kubernetes kubeconfig 文件
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取脚本目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
KUBEXM_ROOT="${KUBEXM_ROOT:-$KUBEXM_SCRIPT_ROOT}"

# 加载依赖
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"

#######################################
# 生成通用 kubeconfig
# Arguments:
#   $1 - 输出文件路径
#   $2 - API Server 地址 (如 https://192.168.1.10:6443)
#   $3 - CA 证书路径
#   $4 - 客户端证书路径
#   $5 - 客户端密钥路径
#   $6 - 用户名
#   $7 - 集群名称 (可选)
# Returns:
#   0 成功, 1 失败
#######################################
kubeconfig::generate() {
  local output_file="$1"
  local api_server="$2"
  local ca_cert="$3"
  local client_cert="$4"
  local client_key="$5"
  local username="$6"
  local cluster_name="${7:-$(defaults::get_cluster_name)}"

  log::info "Generating kubeconfig: ${output_file}"

  # 验证输入文件存在
  if [[ ! -f "${ca_cert}" ]]; then
    log::error "CA certificate not found: ${ca_cert}"
    return 1
  fi
  if [[ ! -f "${client_cert}" ]]; then
    log::error "Client certificate not found: ${client_cert}"
    return 1
  fi
  if [[ ! -f "${client_key}" ]]; then
    log::error "Client key not found: ${client_key}"
    return 1
  fi

  # Base64 编码证书
  local ca_data
  ca_data=$(base64 -w 0 "${ca_cert}")
  local cert_data
  cert_data=$(base64 -w 0 "${client_cert}")
  local key_data
  key_data=$(base64 -w 0 "${client_key}")

  # 创建输出目录
  mkdir -p "$(dirname "${output_file}")"

  # 生成 kubeconfig
  # NOTE: 使用 <<"EOF" (双引号 delimiter) 防止 heredoc 内容被双展开，
  # 允许 ${var} 在 heredoc 中正常展开，但阻止 $(cmd)/`cmd` 等命令替换
  # 被意外执行（如果变量值中包含这些字符）。等同于 << 'EOF' 的安全性。
  cat > "${output_file}" << "EOF"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${ca_data}
    server: ${api_server}
  name: ${cluster_name}
contexts:
- context:
    cluster: ${cluster_name}
    user: ${username}
  name: ${username}@${cluster_name}
current-context: ${username}@${cluster_name}
preferences: {}
users:
- name: ${username}
  user:
    client-certificate-data: ${cert_data}
    client-key-data: ${key_data}
EOF

  chmod 600 "${output_file}"
  log::success "Kubeconfig generated: ${output_file}"
  return 0
}

#######################################
# 生成 admin.conf
# Arguments:
#   $1 - 输出目录
#   $2 - API Server 地址
#   $3 - CA 证书路径
#   $4 - admin 证书路径
#   $5 - admin 密钥路径
#######################################
kubeconfig::generate_admin() {
  local output_dir="$1"
  local api_server="$2"
  local ca_cert="$3"
  local admin_cert="$4"
  local admin_key="$5"

  kubeconfig::generate \
    "${output_dir}/admin.conf" \
    "${api_server}" \
    "${ca_cert}" \
    "${admin_cert}" \
    "${admin_key}" \
    "kubernetes-admin"

  # 兼容常用命名
  if [[ -f "${output_dir}/admin.conf" ]]; then
    cp "${output_dir}/admin.conf" "${output_dir}/admin.kubeconfig" 2>/dev/null || true
  fi
}

#######################################
# 生成 kubelet.conf
# Arguments:
#   $1 - 输出目录
#   $2 - API Server 地址
#   $3 - CA 证书路径
#   $4 - kubelet 证书路径
#   $5 - kubelet 密钥路径
#   $6 - 节点名称
#######################################
kubeconfig::generate_kubelet() {
  local output_dir="$1"
  local api_server="$2"
  local ca_cert="$3"
  local kubelet_cert="$4"
  local kubelet_key="$5"
  local node_name="$6"

  kubeconfig::generate \
    "${output_dir}/kubelet.kubeconfig" \
    "${api_server}" \
    "${ca_cert}" \
    "${kubelet_cert}" \
    "${kubelet_key}" \
    "system:node:${node_name}"

  if [[ -f "${output_dir}/kubelet.kubeconfig" ]]; then
    cp "${output_dir}/kubelet.kubeconfig" "${output_dir}/kubelet.conf" 2>/dev/null || true
  fi
}

#######################################
# 生成 controller-manager.conf
# Arguments:
#   $1 - 输出目录
#   $2 - API Server 地址
#   $3 - CA 证书路径
#   $4 - controller-manager 证书路径
#   $5 - controller-manager 密钥路径
#######################################
kubeconfig::generate_controller_manager() {
  local output_dir="$1"
  local api_server="$2"
  local ca_cert="$3"
  local cm_cert="$4"
  local cm_key="$5"

  kubeconfig::generate \
    "${output_dir}/controller-manager.kubeconfig" \
    "${api_server}" \
    "${ca_cert}" \
    "${cm_cert}" \
    "${cm_key}" \
    "system:kube-controller-manager"

  if [[ -f "${output_dir}/controller-manager.kubeconfig" ]]; then
    cp "${output_dir}/controller-manager.kubeconfig" "${output_dir}/controller-manager.conf" 2>/dev/null || true
  fi
}

#######################################
# 生成 scheduler.conf
# Arguments:
#   $1 - 输出目录
#   $2 - API Server 地址
#   $3 - CA 证书路径
#   $4 - scheduler 证书路径
#   $5 - scheduler 密钥路径
#######################################
kubeconfig::generate_scheduler() {
  local output_dir="$1"
  local api_server="$2"
  local ca_cert="$3"
  local scheduler_cert="$4"
  local scheduler_key="$5"

  kubeconfig::generate \
    "${output_dir}/scheduler.kubeconfig" \
    "${api_server}" \
    "${ca_cert}" \
    "${scheduler_cert}" \
    "${scheduler_key}" \
    "system:kube-scheduler"

  if [[ -f "${output_dir}/scheduler.kubeconfig" ]]; then
    cp "${output_dir}/scheduler.kubeconfig" "${output_dir}/scheduler.conf" 2>/dev/null || true
  fi
}

#######################################
# 生成 kube-proxy.conf (kubexm二进制模式)
# Arguments:
#   $1 - 输出目录
#   $2 - API Server 地址
#   $3 - CA 证书路径
#   $4 - kube-proxy 证书路径
#   $5 - kube-proxy 密钥路径
#######################################
kubeconfig::generate_kube_proxy() {
  local output_dir="$1"
  local api_server="$2"
  local ca_cert="$3"
  local proxy_cert="$4"
  local proxy_key="$5"

  kubeconfig::generate \
    "${output_dir}/kube-proxy.kubeconfig" \
    "${api_server}" \
    "${ca_cert}" \
    "${proxy_cert}" \
    "${proxy_key}" \
    "system:kube-proxy"

  if [[ -f "${output_dir}/kube-proxy.kubeconfig" ]]; then
    cp "${output_dir}/kube-proxy.kubeconfig" "${output_dir}/kube-proxy.conf" 2>/dev/null || true
  fi
}

#######################################
# 生成所有 kubeconfig
# Arguments:
#   $1 - 输出目录
#   $2 - API Server 地址
#   $3 - PKI 目录 (包含所有证书)
#   $4 - 节点名称 (用于 kubelet)
#   $5 - 部署类型 (kubeadm|kubexm) - 可选
#######################################
kubeconfig::generate_all() {
  local output_dir="$1"
  local api_server="$2"
  local pki_dir="$3"
  local node_name="${4:-$(hostname)}"
  local deploy_type="${5:-$(config::get_kubernetes_type 2>/dev/null || echo kubeadm)}"

  log::info "Generating all kubeconfigs for node: ${node_name} (${deploy_type} mode)"

  mkdir -p "${output_dir}"

  # admin.conf
  if [[ -f "${pki_dir}/apiserver-kubelet-client.crt" ]]; then
    kubeconfig::generate_admin \
      "${output_dir}" \
      "${api_server}" \
      "${pki_dir}/ca.crt" \
      "${pki_dir}/apiserver-kubelet-client.crt" \
      "${pki_dir}/apiserver-kubelet-client.key"
  fi

  # controller-manager.conf
  if [[ -f "${pki_dir}/controller-manager.crt" ]]; then
    kubeconfig::generate_controller_manager \
      "${output_dir}" \
      "${api_server}" \
      "${pki_dir}/ca.crt" \
      "${pki_dir}/controller-manager.crt" \
      "${pki_dir}/controller-manager.key"
  fi

  # scheduler.conf
  if [[ -f "${pki_dir}/scheduler.crt" ]]; then
    kubeconfig::generate_scheduler \
      "${output_dir}" \
      "${api_server}" \
      "${pki_dir}/ca.crt" \
      "${pki_dir}/scheduler.crt" \
      "${pki_dir}/scheduler.key"
  fi

  # kubelet.conf (需要节点特定证书)
  if [[ -f "${pki_dir}/kubelet.crt" ]]; then
    kubeconfig::generate_kubelet \
      "${output_dir}" \
      "${api_server}" \
      "${pki_dir}/ca.crt" \
      "${pki_dir}/kubelet.crt" \
      "${pki_dir}/kubelet.key" \
      "${node_name}"
  fi

  # kube-proxy.conf (仅 kubexm 二进制模式需要)
  if [[ "${deploy_type}" == "kubexm" ]] && [[ -f "${pki_dir}/kube-proxy.crt" ]]; then
    kubeconfig::generate_kube_proxy \
      "${output_dir}" \
      "${api_server}" \
      "${pki_dir}/ca.crt" \
      "${pki_dir}/kube-proxy.crt" \
      "${pki_dir}/kube-proxy.key"
  fi

  log::success "All kubeconfigs generated in: ${output_dir}"
}

# 导出函数
export -f kubeconfig::generate
export -f kubeconfig::generate_admin
export -f kubeconfig::generate_kubelet
export -f kubeconfig::generate_controller_manager
export -f kubeconfig::generate_scheduler
export -f kubeconfig::generate_kube_proxy
export -f kubeconfig::generate_all
